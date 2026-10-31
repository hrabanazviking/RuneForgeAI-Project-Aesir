#!/bin/bash
# J-033 guarded soak driver (purplelongship). Runs the J-022 streamed
# OLMoE session (post-fix vehicle, CPU line, J-030 configuration) as 8
# sequential windows of 256 generated tokens each = 2,048 generated
# tokens across mixed prompt types (J-016 types; see J033_SOAK.md
# sections 3-4 for the pre-registered shape and verdict rules).
#
#   j033_run.sh            -- run all windows from window 1
#   j033_run.sh <N>        -- resume at window N (1..8); earlier
#                             windows' logs are kept and counted
#
# Guard (coordination with the 204 road, J-023 pattern generalised):
# before EVERY window the driver refuses to start while any 204-road
# compute is live (tf_oracle / fr_oracle processes, an s098 driver, or
# a busy GPU), while loadavg-1 exceeds 4.0, or while MemAvailable is
# below 2,000 MB. A tripped guard stops the soak cleanly BETWEEN
# windows (exit 3): completed windows remain valid partial evidence
# and the analyser labels the soak PARTIAL. NO co-runner is used --
# the soak runs on an idle box only (J-033 doc section 3).
# Exit 4 = pre-flight failure (pin mismatch / missing ids / bad ids).
set -u
export PATH=/home/volmarr/.pixi/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/home/volmarr/j022/stage
export CUDA_VISIBLE_DEVICES=
M=/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf
PIN=8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f
BIN=/home/volmarr/j022/test_olmoe_stream_fix
WORK=/home/volmarr/j033
IDS_DIR="$WORK/ids"
CTX=512
CACHE_BYTES=536870912
GEN=256
START_AT="${1:-1}"
mkdir -p "$WORK"

# window table: N|type|ids_file  (ids produced per J033_SOAK.md sec.7
# step 2; w01 reuses the verified J-022 ids file directly)
WINDOWS=(
  "1|prose|/home/volmarr/j022/prompt_prose_ids.csv"
  "2|code|$IDS_DIR/code_ids.csv"
  "3|structured|$IDS_DIR/structured_ids.csv"
  "4|numbers|$IDS_DIR/numbers_ids.csv"
  "5|instructions|$IDS_DIR/instructions_ids.csv"
  "6|technical|$IDS_DIR/technical_ids.csv"
  "7|prose2|$IDS_DIR/prose2_ids.csv"
  "8|code2|$IDS_DIR/code2_ids.csv"
)

state_line() {
  local load tctl memavail gpu
  load=$(cut -d' ' -f1-3 /proc/loadavg)
  tctl=$(sensors 2>/dev/null | grep -i 'Tctl' | awk '{print $2}')
  memavail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  gpu=$(nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader 2>/dev/null)
  echo "loadavg=$load tctl=$tctl mem_available_kb=$memavail gpu=$gpu"
}

guard_blocked() {
  # echoes a reason and returns 0 when the soak must not proceed
  if pgrep -f 'tf_oracle|fr_oracle' >/dev/null; then
    echo "oracle_compute_live"; return 0
  fi
  if pgrep -f 's098' >/dev/null; then
    echo "s098_live"; return 0
  fi
  local l1 memavail_kb gpu_used
  l1=$(cut -d' ' -f1 /proc/loadavg)
  memavail_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  gpu_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo 0)
  if awk "BEGIN{exit !($l1 > 4.0)}"; then
    echo "loadavg1=$l1"; return 0
  fi
  if [ "$memavail_kb" -lt 2000000 ]; then
    echo "mem_available_kb=$memavail_kb"; return 0
  fi
  if [ "${gpu_used:-0}" -gt 100 ]; then
    echo "gpu_used_mib=$gpu_used"; return 0
  fi
  return 1
}

# ---- pre-flight ----------------------------------------------------
ACTUAL_PIN=$(sha256sum "$M" | awk '{print $1}')
if [ "$ACTUAL_PIN" != "$PIN" ]; then
  echo "PREFLIGHT_FAIL model pin mismatch: $ACTUAL_PIN" | tee "$WORK/soak_summary.txt"
  exit 4
fi
if [ ! -x "$BIN" ]; then
  echo "PREFLIGHT_FAIL vehicle missing: $BIN" | tee "$WORK/soak_summary.txt"
  exit 4
fi
for row in "${WINDOWS[@]}"; do
  IFS='|' read -r n typ ids <<< "$row"
  if [ ! -f "$ids" ]; then
    echo "PREFLIGHT_FAIL window $n ($typ): ids file missing: $ids" | tee -a "$WORK/soak_summary.txt"
    exit 4
  fi
  cnt=$(tr ',' '\n' < "$ids" | grep -c .)
  if [ "$cnt" -gt 200 ]; then
    echo "PREFLIGHT_FAIL window $n ($typ): prompt $cnt ids over the 200-id pre-registered bound" | tee -a "$WORK/soak_summary.txt"
    exit 4
  fi
  echo "window $n type=$typ prompt_ids=$cnt gen_target=$GEN" >> "$WORK/soak_summary.txt"
done
echo "PREFLIGHT_OK pin=$ACTUAL_PIN time=$(date -Is)" | tee -a "$WORK/soak_summary.txt"

# ---- windows -------------------------------------------------------
for row in "${WINDOWS[@]}"; do
  IFS='|' read -r n typ ids <<< "$row"
  if [ "$n" -lt "$START_AT" ]; then continue; fi
  OUT="$WORK/run_w0$n.log"
  META="$WORK/run_w0$n.meta"
  {
    echo "WINDOW=$n type=$typ time=$(date -Is)"
    echo "start: $(state_line)"
  } > "$META"
  if reason=$(guard_blocked); then
    echo "GUARD_BLOCKED window=$n reason=$reason" | tee -a "$META" "$WORK/soak_summary.txt"
    echo "SOAK_STOPPED_BETWEEN_WINDOWS completed_windows_below=$((n-1))"
    exit 3
  fi
  IDS=$(cat "$ids")
  /usr/bin/time -v nice -n 10 "$BIN" "$M" $CTX $CACHE_BYTES "$IDS" $GEN > "$OUT" 2> "$WORK/run_w0$n.time"
  RC=$?
  echo "RUN_EXIT=$RC window=$n" | tee -a "$META"
  grep -E 'Maximum resident|Elapsed \(wall' "$WORK/run_w0$n.time" >> "$META" 2>/dev/null
  echo "end: $(state_line)" >> "$META"
  grep 'Generated IDs' "$OUT" | head -c 200 >> "$WORK/soak_summary.txt" || true
  echo "" >> "$WORK/soak_summary.txt"
  echo "WINDOW_DONE window=$n type=$typ rc=$RC"
  if [ "$RC" -ne 0 ]; then
    echo "SOAK_ABORTED window=$n rc=$RC" | tee -a "$WORK/soak_summary.txt"
    exit 5
  fi
done
echo "SOAK_ALL_WINDOWS_DONE time=$(date -Is)" | tee -a "$WORK/soak_summary.txt"
