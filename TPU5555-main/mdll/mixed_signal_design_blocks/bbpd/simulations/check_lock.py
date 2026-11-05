#!/usr/bin/env python3
"""Acceptance gate for the closed-loop MDLL run (test_fine_loop.sch).

Everything else in this block is checked in isolation: the accumulator is
proved by BMC, the mapped netlist by SAT, the comparator's polarity by a
delay sweep. None of that says the pieces are wired together in the direction
that makes the loop converge. This does.

Reads simulations/test_fine_loop.raw (ngspice ASCII raw) and checks:

  1. The loop CLOSES -- comp changes value during the run, i.e. the code
     crossed the lock point rather than walking into a rail.
  2. The code walks the RIGHT WAY -- seeded below the lock code, it must
     increase (clk_gen's cap bank is code-up => frequency-down, so a ring
     that is too fast needs a higher code).
  3. It SETTLES -- after the walk, the code stays inside a narrow dither band
     instead of drifting or oscillating across the range.
  4. The DIVIDE RATIO is what the architecture claims. clk_gen is meant to
     put N=4 DCO cycles between injections; if it does not, the output is not
     a clean multiple of the reference no matter how well the loop converges.
  5. The phase error is BOUNDED. In an MDLL the injection re-aligns the ring
     to the reference every period, so the error is memoryless: it depends on
     the current code, not on the previous error. If instead it ramps, the
     reference is not re-timing the injection, and a phase detector feeding an
     integrator then has two integrators in the loop -- which limit-cycles
     rather than locking, no matter how good the comparator is.
  6. The RESIDUAL is small. At lock the ring's free-running period should
     satisfy 4*T_DCO = T_REF. It will not, exactly: the comparator has a
     static offset (see check_pd.py), so the loop parks where div is late by
     that offset, and the injection absorbs the difference every reference
     cycle. That absorbed error is the reference spur. It is measured here as
     the difference between the injected DCO cycle and the free-running ones.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DECK = os.path.join(ROOT, "build", "test_fine_loop.spice")
VTH  = 0.6


def deck_params(path=DECK):
    """SEED / T_REF straight out of the generated deck.

    They are set in test_fine_loop.sch, so reading them here keeps the checker from
    silently disagreeing with the run it is checking -- which is exactly what
    happened when the seed was a CLI default.
    """
    import re
    out = {}
    if os.path.exists(path):
        for m in re.finditer(r"^\.PARAM\s+(\w+)\s*=\s*(\S+)", open(path).read(),
                             re.M | re.I):
            out[m.group(1).upper()] = m.group(2)
    return out


def read_raw(path):
    """Parse an ngspice ASCII raw file -> (names, [rows]).

    Not wrdata: a bracketed node name like C[7] cannot be passed to wrdata
    without quoting, and a quote cannot survive xschem's value="..." attribute.
    The raw file sidesteps all of that -- every saved vector appears under its
    real name in the Variables block.
    """
    names, rows, mode, nvars, npts = [], [], None, 0, 0
    with open(path) as f:
        for line in f:
            s = line.strip()
            if s.startswith("No. Variables:"):
                nvars = int(s.split(":")[1])
                continue
            if s.startswith("No. Points:"):
                npts = int(s.split(":")[1])
                continue
            if s.startswith("Variables:"):
                mode = "vars"
                continue
            if s.startswith("Values:"):
                mode = "vals"
                cur = []
                continue
            if mode == "vars" and s:
                names.append(s.split()[1])
                continue
            if mode == "vals" and s:
                parts = s.split()
                # A point starts with its index; continuation lines are bare.
                cur.append(float(parts[1] if len(parts) > 1 else parts[0]))
                if len(cur) == nvars:
                    rows.append(cur)
                    cur = []
    if not rows:
        raise SystemExit(f"{path}: no data -- is it an ASCII raw file? "
                         "The deck needs `set filetype=ascii` before `write`.")
    if npts and len(rows) != npts:
        print(f"note: header says {npts} points, parsed {len(rows)}")
    return names, rows


def col(names, rows, want):
    """Fetch a vector by node name.

    ngspice lower-cases node names in the raw file and wraps them as v(...),
    so C[7] comes back as 'v(c[7])'. Match case-insensitively on both spellings
    rather than making the caller know that.
    """
    cands = {want.lower(), f"v({want.lower()})"}
    for i, n in enumerate(names):
        if n.lower() in cands:
            return [r[i] for r in rows]
    raise SystemExit(f"column {want!r} not in {names}")


def rising(t, v, vth=VTH):
    """Interpolated rising-edge times."""
    out = []
    for i in range(1, len(v)):
        if v[i - 1] <= vth < v[i]:
            f = (vth - v[i - 1]) / (v[i] - v[i - 1])
            out.append(t[i - 1] + f * (t[i] - t[i - 1]))
    return out


def sample(t, v, at):
    """Value of v at time `at` (previous sample; signals here are digital)."""
    lo, hi = 0, len(t) - 1
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if t[mid] <= at:
            lo = mid
        else:
            hi = mid - 1
    return v[lo]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(HERE, "test_fine_loop.raw"))
    dp = deck_params()

    def _t(v, dflt):
        try:
            return float(v.replace("n", "e-9").replace("p", "e-12"))
        except (AttributeError, ValueError):
            return dflt

    ap.add_argument("--tref", type=float, default=_t(dp.get("T_REF"), 10e-9))
    ap.add_argument("--ndiv", type=int, default=4,
                    help="clk_gen's divide ratio (fixed at 4)")
    ap.add_argument("--seed", type=int, default=int(dp.get("SEED", 72)))
    ap.add_argument("--settle-cycles", type=int, default=8,
                    help="reference cycles after lock needed to judge dither")
    ap.add_argument("--skip-cycles", type=int, default=1,
                    help="leading cycles to drop (the reset code, before the "
                         "one-shot load takes effect)")
    a = ap.parse_args()

    if not os.path.exists(a.raw):
        sys.exit(f"missing {a.raw} -- run `make fine_loop_sim`")

    names, rows = read_raw(a.raw)
    t   = [r[0] for r in rows]
    ref = col(names, rows, "clk_ref")
    dvv = col(names, rows, "div")
    selv = col(names, rows, "sel")
    out = col(names, rows, "clk_out")
    cmp_ = col(names, rows, "comp")
    bits = [col(names, rows, f"C[{b}]") for b in range(7, -1, -1)]

    # --- code trajectory, sampled mid-reference-cycle where it is stable ----
    #
    # Alongside the code, record the quantity the comparator is actually
    # deciding on: t_div - t_clk_ref for this reference cycle. That is the
    # loop's error signal, and watching it converge says far more than the
    # code trajectory alone -- a code that walks tells you the loop is moving,
    # the error tells you whether it is moving toward anything.
    ref_edges = rising(t, ref)
    div_edges = rising(t, dvv)
    traj = []
    for e in ref_edges:
        ts = e + 0.7 * a.tref
        if ts > t[-1]:
            break
        code = 0
        for b in bits:
            code = (code << 1) | (1 if sample(t, b, ts) > VTH else 0)
        # The div pulse belonging to this reference cycle is the one nearest
        # the edge. Half a reference period is the widest unambiguous window:
        # beyond that, "nearest" could pick a neighbouring pulse.
        near = [d for d in div_edges if abs(d - e) < 0.5 * a.tref]
        dt = min(near, key=lambda d: abs(d - e)) - e if near else None
        traj.append((e, code, 1 if sample(t, cmp_, ts) > VTH else 0, dt))

    if len(traj) < a.skip_cycles + a.settle_cycles + 4:
        sys.exit(f"only {len(traj)} reference cycles captured -- "
                 "extend the transient")

    # Cycle 0 shows RESET_CODE; the one-shot `load` pulse overwrites it with
    # `seed` on the first clk_ref edge after reset release. Drop it.
    #
    # WARMUP is the cycle after that. Its code is the seed, but its comp was
    # decided while the ring was still running at RESET_CODE, so the step it
    # produces is meaningless -- the direction and lock analysis starts after
    # it.
    WARMUP = 1
    traj  = traj[a.skip_cycles:]
    codes = [c for _, c, _, _ in traj]
    comps = [c for _, _, c, _ in traj]
    dts   = [d for _, _, _, d in traj]

    print(f"reference cycles : {len(traj)} "
          f"({a.skip_cycles} skipped: the reset code, before the load lands)")
    print(f"seed             : {a.seed} (DCO code {a.seed >> 2})")
    print("code trajectory  : " + " ".join(str(c) for c in codes))
    print("comp             : " + " ".join(str(c) for c in comps))
    print("\nphase error t_div - t_clk_ref, every 4th reference cycle:")
    for i in range(0, len(traj), 4):
        d = dts[i]
        print(f"  cyc {i:>3}  code {codes[i]:>3} (DCO {codes[i] >> 2:>2})  "
              + (f"{d*1e12:+9.1f} ps" if d is not None else "    (no div edge)"))
    if (len(traj) - 1) % 4:
        i = len(traj) - 1
        d = dts[i]
        print(f"  cyc {i:>3}  code {codes[i]:>3} (DCO {codes[i] >> 2:>2})  "
              + (f"{d*1e12:+9.1f} ps" if d is not None else "    (no div edge)"))

    ok = True

    if codes[0] != a.seed:
        ok = False
        print(f"\nFAIL: first post-load code is {codes[0]}, expected the seed "
              f"{a.seed}. The load path is not doing what the deck assumes.")

    # --- 1. did the loop cross lock? -----------------------------------------
    # comp holds one value while the code walks, and starts alternating once
    # the ring passes the comparator's decision point. The first change is the
    # lock instant.
    lock = next((i for i in range(WARMUP + 1, len(comps))
                 if comps[i] != comps[WARMUP]), None)

    if lock is None:
        ok = False
        direction = "up" if codes[-1] > codes[WARMUP] else "down"
        print(f"\nFAIL: comp never changed (held at {comps[WARMUP]}). The code "
              f"walked {direction} from {codes[WARMUP]} to {codes[-1]} without "
              "reaching the decision point -- either the run is too short or "
              "the seed is too far out.")
        lock = len(comps) - 1
    else:
        print(f"\nlock reached     : reference cycle {lock} "
              f"(code {codes[lock]}, DCO code {codes[lock] >> 2})")

    # --- 2. direction ---------------------------------------------------------
    walk = codes[lock] - codes[WARMUP]
    if walk < 0 and comps[WARMUP] == 0:
        # comp = 0 means "div early, ring too fast", so the code must rise.
        # Walking down while comp says 0 is an inverted loop. If comp starts
        # at 1 the seed was already past the crossing and walking down is
        # correct, so do not cry wolf.
        ok = False
        print(f"FAIL: comp reads 0 (ring too fast) but the code walked DOWN "
              f"({walk}). The sign of the loop is inverted.")
    elif walk < 0:
        print(f"walk             : {walk} LSB downward (seed was above the "
              f"crossing; comp started at 1)")
    elif walk > 0:
        print(f"walk             : +{walk} LSB, monotonic "
              f"{'yes' if all(b >= a_ for a_, b in zip(codes[WARMUP:lock], codes[WARMUP + 1:lock + 1])) else 'NO'}")

    # --- 3. settling ----------------------------------------------------------
    post = codes[lock:]
    if len(post) < a.settle_cycles:
        ok = False
        print(f"FAIL: only {len(post)} cycle(s) after lock; need "
              f"{a.settle_cycles} to judge the dither. Extend the transient.")
        settled = post or codes[-1:]
    else:
        settled = post[-a.settle_cycles:]

    band = max(settled) - min(settled)
    print(f"final code       : {codes[-1]} (DCO code {codes[-1] >> 2})")
    print(f"dither band      : {band} LSB over the last {len(settled)} cycles "
          f"({min(settled)}..{max(settled)})")

    settled_dt = [d for d in dts[-len(settled):] if d is not None]
    if settled_dt:
        print(f"settled error    : {sum(settled_dt)/len(settled_dt)*1e12:+.1f} ps mean, "
              f"{min(settled_dt)*1e12:+.1f} .. {max(settled_dt)*1e12:+.1f} ps")
        print("                   compare with the comparator's static offset "
              "from check_pd.py -- the loop parks where the COMPARATOR reads "
              "zero, not where the error is zero.")

    if codes[-1] in (0, 255):
        ok = False
        print("FAIL: the code is sitting on a rail -- the loop ran away.")
    elif len(post) >= a.settle_cycles and band > 4:
        ok = False
        print(f"FAIL: dither band {band} LSB is too wide to call this settled.")

    # --- 4. divide ratio ------------------------------------------------------
    #
    # The loop can converge beautifully and still be multiplying by the wrong
    # number: the comparator only sees whether div lands on the reference edge,
    # never how many DCO cycles went by in between. Nothing in the code
    # trajectory reveals the ratio -- you have to count.
    #
    # The window that defines it is from the divider's reset RELEASE (sel
    # falling, since div_rstb = Resetb AND Selb) to div rising.
    inj_fall = rising(t, [1.2 - v for v in selv])
    div_rise = rising(t, dvv)
    dco_all  = rising(t, out)
    counts = []
    for f in inj_fall:
        nxt = [d for d in div_rise if d > f]
        if not nxt or nxt[0] - f > 1.5 * a.tref:
            continue
        counts.append(sum(1 for o in dco_all if f < o <= nxt[0]))

    # Only the settled tail is meaningful: while the code is still walking the
    # ring is off-frequency and the count legitimately differs.
    counts = counts[-len(settled):] if len(counts) > len(settled) else counts
    if counts:
        hist = {}
        for c in counts:
            hist[c] = hist.get(c, 0) + 1
        print("\ndivide ratio     : " + ", ".join(
            f"{c} DCO cycles x{n}" for c, n in sorted(hist.items()))
            + f"   (expected {a.ndiv})")
        mode = max(hist, key=hist.get)
        if mode != a.ndiv:
            ok = False
            print(f"FAIL: {mode} DCO cycles between injections, expected "
                  f"{a.ndiv}. The output is not an integer multiple of the "
                  f"reference at the intended ratio.")
        if len(hist) > 1:
            ok = False
            print("FAIL: the count is not constant. The divider's reset is "
                  "released asynchronously to clk_out, so whether the edge "
                  "nearest the release gets counted is a coin flip -- the "
                  "same defect STA reports as a removal violation on the "
                  "divider flops' RESET_B.")

    # --- 5. is the phase error bounded? --------------------------------------
    #
    # This is the check that distinguishes "an MDLL that has not settled yet"
    # from "not an MDLL". Injection should reset the phase each reference
    # period; the error then lives within a fraction of a DCO period. A steady
    # ramp instead means the ring free-runs between injections and the error
    # integrates.
    #
    # Judged over the settled window only, as check 6: during the walk the
    # code moves one LSB per cycle, so the error moves monotonically by design
    # (seeded below lock it rises for the whole walk), which says nothing about
    # injection.
    first = max(lock, len(dts) - a.settle_cycles)
    known = [(i, d) for i, d in enumerate(dts) if d is not None and i >= first]
    if len(known) >= 6:
        pk = max(d for _, d in known) - min(d for _, d in known)
        steps = [b - a_ for (_, a_), (_, b) in zip(known, known[1:])]
        print(f"\nphase error range: {pk*1e12:.0f} ps peak-to-peak over "
              f"the last {len(known)} cycles")
        # Consecutive same-sign steps are the signature of a ramp.
        run, best = 1, 1
        for x, y in zip(steps, steps[1:]):
            run = run + 1 if (x > 0) == (y > 0) else 1
            best = max(best, run)
        print(f"                   longest monotonic run: {best} cycles "
              f"(mean step {sum(steps)/len(steps)*1e12:+.0f} ps)")
        if best >= 5:
            ok = False
            print("FAIL: the phase error RAMPS rather than staying bounded. "
                  "The injection is not re-aligning the ring to the reference "
                  "-- clk_gen's selector generates `sel` from the divider and "
                  "the ring only; clk_ref never re-times it. The error then "
                  "integrates, so this loop has two integrators and will "
                  "limit-cycle instead of locking. Fix the selector (gate sel "
                  "with clk_ref) or add a proportional path to the filter.")

    # --- 6. residual ----------------------------------------------------------
    # Measured only over the settled window, where the code is no longer moving.
    t_lock = traj[min(max(lock, len(traj) - a.settle_cycles), len(traj) - 1)][0]
    dco = [x for x in rising(t, out) if x > t_lock]
    periods = sorted(b - a_ for a_, b in zip(dco, dco[1:]))
    if len(periods) >= a.ndiv * 2:
        # One DCO cycle in every ndiv is the injected one: the reference edge
        # replaces the ring's own edge, so that cycle is stretched (ring too
        # fast) or truncated (ring too slow). Either way it is the outlier, so
        # discard by DISTANCE FROM THE MEDIAN rather than by taking the
        # shortest -- which would silently pick the wrong set whenever the
        # residual changes sign, i.e. exactly at lock.
        med = periods[len(periods) // 2]
        n_drop = max(1, len(periods) // a.ndiv)
        free = sorted(periods, key=lambda x: abs(x - med))[:len(periods) - n_drop]
        t_free = sum(free) / len(free)
        injected = [p_ for p_ in periods if p_ not in free]
        resid = a.ndiv * t_free - a.tref
        print(f"\nfree-running DCO : {t_free*1e12:.1f} ps "
              f"({1/t_free/1e6:.1f} MHz), target {a.tref/a.ndiv*1e12:.1f} ps")
        if injected:
            print(f"injected cycle   : {sum(injected)/len(injected)*1e12:.1f} ps "
                  f"({len(injected)} of {len(periods)})")
        print(f"residual/ref cyc : {resid*1e12:+.1f} ps  "
              f"({abs(resid)/a.tref*100:.2f} % of T_REF)")
        print("                   the injection absorbs this every reference "
              "cycle -- i.e. the reference spur. Compare it with the "
              "comparator's static offset from check_pd.py; the loop parks "
              "where the comparator says zero, not where the error is zero.")
        if abs(resid) > 0.05 * a.tref:
            ok = False
            print("FAIL: residual exceeds 5 % of the reference period.")
    else:
        print("\n(not enough clk_out edges after lock to measure the residual)")

    print("\nPASS" if ok else "\nFAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
