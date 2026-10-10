#!/bin/bash
# H164 — GEMM tiling sweep driver (runs on Mimir).
# 12 configs x {1024^3, 4096^3}, 5 trials each. Results -> gemm_sweep_1.json
# Usage: ./bench/h164_sweep.sh  (assumes build/run_bench is the H164 binary)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGS=(
  "64 256 64 0 0 0"
  "128 256 64 0 0 0"
  "64 256 128 0 0 0"
  "64 512 64 0 0 0"
  "32 128 32 0 0 0"
  "64 256 64 0 1 0"
  "64 256 64 0 0 1"
  "64 256 64 0 1 1"
  "64 256 64 64 0 0"
  "64 256 64 128 1 0"
  "128 512 128 0 1 1"
  "64 128 64 0 1 0"
)

OUT="data/bench/gemm_sweep_1.json"
echo "{" > "$OUT"
echo '  "slice": "H164",' >> "$OUT"
echo '  "configs": [' >> "$OUT"

first=1
i=0
for cfg in "${CONFIGS[@]}"; do
  i=$((i+1))
  set -- $cfg
  mc=$1; kc=$2; nc=$3; pf=$4; hoist=$5; micro=$6
  for shape in "1024" "4096"; do
    M=$shape; N=$shape; K=$shape
    out="data/bench/sweep_c${i}_${shape}.json"
    echo "=== config $i/12 mc=$mc kc=$kc nc=$nc pf=$pf hoist=$hoist micro=$micro ${M}^3 ==="
    ./bench/run.sh --bench gemm_tuned --out "sweep_c${i}_${shape}" \
      --M $M --N $N --K $K --mc $mc --kc $kc --nc $nc \
      --prefetch $pf --hoist $hoist --micro $micro \
      --warmup 2 --trials 5 > /dev/null 2>&1
    # extract median GFLOPS
    gflops=$(python3 -c "import json; d=json.load(open('$out')); print(d['results'][0]['median'])")
    if [ $first -eq 1 ]; then first=0; else echo "," >> "$OUT"; fi
    printf '    {"config": %d, "M": %d, "mc": %d, "kc": %d, "nc": %d, "prefetch": %d, "hoist": %d, "micro": %d, "gflops": %.4f}' \
      "$i" "$M" "$mc" "$kc" "$nc" "$pf" "$hoist" "$micro" "$gflops" >> "$OUT"
    echo "  -> $gflops GFLOPS"
  done
done
echo "" >> "$OUT"
echo '  ]' >> "$OUT"
echo "}" >> "$OUT"
echo "wrote $OUT"
