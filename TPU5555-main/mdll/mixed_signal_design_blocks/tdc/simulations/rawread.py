"""Minimal reader for ngspice ASCII raw files (one real-valued plot).

Pure python -- numpy is not available in this environment.
"""


def read(path):
    names, cols, nvar = [], [], 0
    with open(path) as f:
        for line in f:
            if line.startswith("No. Variables:"):
                nvar = int(line.split(":")[1])
            elif line.startswith("Variables:"):
                for _ in range(nvar):
                    names.append(next(f).split()[1])
                cols = [[] for _ in range(nvar)]
            elif line.startswith("Values:"):
                i = 0
                for line in f:
                    tok = line.split()
                    if not tok:
                        continue
                    cols[i].append(float(tok[-1]))
                    i = (i + 1) % nvar
    n = min(len(c) for c in cols)
    return {name: c[:n] for name, c in zip(names, cols)}


def edges(t, v, vth, rising=True):
    """Linearly interpolated threshold-crossing times."""
    out = []
    for i in range(len(v) - 1):
        a, b = v[i], v[i + 1]
        if (a <= vth < b) if rising else (a > vth >= b):
            out.append(t[i] + (vth - a) * (t[i + 1] - t[i]) / (b - a))
    return out


def value_at(t, v, tq):
    """v at time tq (linear interpolation; t is sorted)."""
    lo, hi = 0, len(t) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if t[mid] <= tq:
            lo = mid
        else:
            hi = mid
    if t[hi] == t[lo]:
        return v[lo]
    return v[lo] + (v[hi] - v[lo]) * (tq - t[lo]) / (t[hi] - t[lo])


def word(d, t, prefix, width, tq, vth):
    """Integer value of bus prefix[width-1..0] at time tq."""
    x = 0
    for b in range(width):
        if value_at(t, d[f"{prefix}[{b}]"], tq) > vth:
            x |= 1 << b
    return x
