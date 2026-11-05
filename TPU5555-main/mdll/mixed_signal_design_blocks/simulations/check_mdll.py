#!/usr/bin/env python3
"""Acceptance gate for the closed-loop MDLL run (test_mdll.sch).

lock_ctrl's `make sim_acq` checks the acquisition LOGIC against behavioural
models. This checks that the transistor-level blocks behave the way those
models assumed. Reads simulations/test_mdll.raw and checks:

  1. Handover happens, exactly once, within MAX_LOCK reference cycles.
  2. After handover lock_ctrl is out of the loop: load stays low.
  0. The code is START from the first reference edge after reset (dlf's reset
     code; mdll.sch's start controller).
  3. During the coarse phase the code never moves DOWN (towards faster) from
     lock_ctrl's START code -- acquisition approaches from the fast side.
  4. No coarse jump overshoots the final lock point by more than one DCO step:
     the TDC cannot see the slow side, so an overshoot there would go unseen.
  5. After handover the bang-bang loop settles into a narrow dither band.
  6. The lock is faster than bang-bang alone would be from mid-band (0x80,
     one DCO step per four reference cycles) -- a loop without lock_ctrl.
     (dlf's reset code used to be 0x80; it is START now.)
  7. The dither is a lock, not a saturation: after handover the 8-bit code
     never sits at dlf's limits (0x00, 0xFF) and does not stay constant. A
     DCO that cannot reach the reference at its fastest code pins the code
     at 0x00 -- the bbpd says "too slow" every cycle -- and passed 1-6 as a
     "band 0..0" (Calibre RC run at ss, 2026-10-28).
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tdc", "simulations"))
import rawread  # noqa: E402

MAX_LOCK = 100          # reference cycles
SETTLE = 40             # cycles after handover before the dither band is judged
BAND = 2                # 6-bit codes: dither must stay within this span
BB_REF_CODE6 = 0x80 >> 2  # check 6's baseline: bang-bang from mid-band


def lock_ctrl_start():
    """lock_ctrl's START parameter (the code acquisition is forced to), read
    from the RTL so that this check cannot drift from it."""
    import re
    src = open(os.path.join(ROOT, "lock_ctrl", "rtl", "lock_ctrl.v")).read()
    m = re.search(r"parameter\s+integer\s+START\s*=\s*8'h([0-9a-fA-F]+)", src)
    if not m:
        sys.exit("check_mdll.py: no `parameter integer START = 8'hNN` in lock_ctrl.v")
    return int(m.group(1), 16)


def dlf_reset_code():
    """dlf's RESET_CODE parameter default (bbpd/rtl/dlf.v)."""
    import re
    src = open(os.path.join(ROOT, "bbpd", "rtl", "dlf.v")).read()
    m = re.search(r"parameter\s+\[7:0\]\s+RESET_CODE\s*=\s*8'h([0-9a-fA-F]+)", src)
    if not m:
        sys.exit("check_mdll.py: no `parameter [7:0] RESET_CODE = 8'hNN` in dlf.v")
    return int(m.group(1), 16)


START = lock_ctrl_start()
# Two macros, one start code: the ring's first run after reset is at dlf's
# reset code and every later one until handover at lock_ctrl's (mdll.sch).
if dlf_reset_code() != START:
    sys.exit(f"check_mdll.py: dlf RESET_CODE 0x{dlf_reset_code():02x} != lock_ctrl "
             f"START 0x{START:02x} -- set both (bbpd/rtl/dlf.v, lock_ctrl/rtl/lock_ctrl.v)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(HERE, "test_mdll.raw"))
    a = ap.parse_args()
    if not os.path.exists(a.raw):
        sys.exit(f"missing {a.raw} -- run `make mdll_sim`")

    d = {(k[2:-1] if k.startswith("v(") else k).lower(): v
         for k, v in rawread.read(a.raw).items()}
    t = d["time"]
    # Logic threshold at half the run's supply, read off clk_ref's high level,
    # so runs at the slow/fast SPICE corners (1.08 / 1.32 V) are graded alike.
    TH = max(d["clk_ref"]) / 2
    refs = [x for x in rawread.edges(t, d["clk_ref"], TH)
            if rawread.value_at(t, d["resetb"], x) > TH]
    if len(refs) < 10:
        sys.exit("FAIL: fewer than 10 reference edges after reset")

    # Sample everything just before each reference edge (setup side).
    samples = []
    for x in refs:
        tq = x - 0.5e-9
        code = rawread.word(d, t, "code", 8, tq, TH)
        samples.append(dict(t=x, code=code, c6=code >> 2,
                            load=rawread.value_at(t, d["x1.load"], tq) > TH,
                            locked=rawread.value_at(t, d["locked"], tq) > TH))

    fails = []
    lk = [i for i, s in enumerate(samples) if s["locked"]]
    rises = sum(1 for p, q in zip(samples, samples[1:]) if q["locked"] and not p["locked"])
    falls = sum(1 for p, q in zip(samples, samples[1:]) if p["locked"] and not q["locked"])

    # 1
    if not lk:
        fails.append(f"no handover in {len(samples)} reference cycles")
        i_lock = None
    else:
        i_lock = lk[0]
        if i_lock > MAX_LOCK:
            fails.append(f"handover at cycle {i_lock} > {MAX_LOCK}")
        if rises != 1 or falls:
            fails.append(f"locked rose {rises}x and fell {falls}x (want 1, 0)")

    # 2
    if i_lock is not None:
        bad = [i for i in range(i_lock, len(samples)) if samples[i]["load"]]
        if bad:
            fails.append(f"load high after handover at cycles {bad[:5]}")

    # 0 -- the first run after reset is already at START: dlf resets to it and
    #      mdll.sch's start controller releases the ring on a clk_ref edge. (A
    #      dlf or lock_ctrl that never responds is caught by check 7: a code
    #      that never moves. A miswired co-simulation once sat at dlf's then
    #      reset code 0x80 and passed every other check, "locked" by
    #      lock_ctrl's ARM timeout.)
    if samples[0]["code"] != START:
        fails.append(f"code 0x{samples[0]['code']:02x} at the first reference edge "
                     f"after reset, not START (0x{START:02x})")

    # 3 -- from the first edge: nothing to skip since the code starts at START
    coarse = samples[:i_lock] if i_lock else samples
    for p, q in zip(coarse, coarse[1:]):
        if q["code"] < p["code"]:
            fails.append(f"coarse code decreased {p['code']} -> {q['code']} at "
                         f"{q['t']*1e9:.1f} ns")
            break

    # 5
    final = samples[i_lock + SETTLE:] if i_lock is not None else []
    if i_lock is not None and not final:
        fails.append(f"run too short: need {SETTLE} cycles after handover")
    lo = min(s["c6"] for s in final) if final else None
    hi = max(s["c6"] for s in final) if final else None
    if final and hi - lo > BAND:
        fails.append(f"final 6-bit code spans {lo}..{hi} (> {BAND})")

    # 4
    if final:
        peak = max(s["c6"] for s in coarse) if coarse else 0
        if peak > hi + 1:
            fails.append(f"coarse overshoot: 6-bit {peak} vs final band {lo}..{hi}")

    # 7
    if final:
        codes = [s["code"] for s in final]
        rail = sorted({c for c in codes if c in (0x00, 0xFF)})
        if rail:
            fails.append(f"code at dlf's limit ({', '.join(f'0x{c:02x}' for c in rail)}) "
                         f"after handover: out of the DCO's range, not locked")
        elif min(codes) == max(codes):
            fails.append(f"code constant at 0x{codes[0]:02x} after handover: "
                         f"the bang-bang loop is not dithering")

    # 6
    if final and i_lock is not None:
        mid = (lo + hi) / 2
        bb = 4 * abs(BB_REF_CODE6 - mid)
        print(f"handover at cycle {i_lock}; bang-bang alone from 0x80 ~{bb:.0f} cycles "
              f"+ dither")
        if i_lock >= bb + SETTLE:
            fails.append(f"no faster than bang-bang alone ({i_lock} vs ~{bb:.0f})")

    jumps = [(p["code"], q["code"]) for p, q in zip(coarse, coarse[1:]) if q["code"] != p["code"]]
    print("coarse jumps: " + (", ".join(f"{x}->{y}" for x, y in jumps) or "none"))
    if final:
        print(f"final 6-bit code band {lo}..{hi} over {len(final)} cycles")
    for f in fails:
        print("FAIL: " + f)
    print("PASS" if not fails else "FAIL")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
