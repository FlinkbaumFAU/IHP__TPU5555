#!/usr/bin/env bash
# Run the DCO characterisation sweep and check it for monotonicity.
#
# Each code is an independent transient (~30-60 s), so the code range is sharded
# across cores and the per-shard CSVs are merged. Serial would be ~35 min.
#
# Usage: run_char.sh [n_shards]   (default: nproc-2)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${CHAR_WORK:-$HERE/../build/char}"
N="${1:-$(( $(nproc) - 2 ))}"
(( N < 1 ))  && N=1

rm -rf "$WORK"; mkdir -p "$WORK"
echo "sharding codes 0..63 across $N ngspice processes -> $WORK"

pids=()
for ((s = 0; s < N; s++)); do
    lo=$(( s * 64 / N ))
    hi=$(( (s + 1) * 64 / N - 1 ))
    (( lo > hi )) && continue
    d="$WORK/shard$s"; mkdir -p "$d"
    python3 "$HERE/gen_char_dco.py" --lo "$lo" --hi "$hi" \
            --csv "part.csv" -o "$d/char_dco.spice" >/dev/null
    ( cd "$d" && ngspice -b char_dco.spice > ngspice.log 2>&1 ) &
    pids+=($!)
done

fail=0
for p in "${pids[@]}"; do wait "$p" || fail=1; done
(( fail )) && { echo "FAIL: at least one ngspice shard exited non-zero"; exit 1; }

# Merge, keeping one header and sorting numerically by code.
{ echo "code freq"
  cat "$WORK"/shard*/part.csv | grep -v '^code ' | sort -n -k1,1
} > "$WORK/dco_char.csv"

echo
python3 "$HERE/check_monotonic.py" "$WORK/dco_char.csv"
