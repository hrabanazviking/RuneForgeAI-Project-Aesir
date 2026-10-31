#!/bin/bash
# J-023 guarded leg driver (purplelongship). One leg per invocation:
#   j023_run.sh idle    -- streamed OLMoE run, no co-runner
#   j023_run.sh loaded  -- same run with the bounded co-runner live
# Guard (coordination with the 204 road's S-093): a leg starts only if
# no S-093 compute process (tf_oracle / fr_oracle / s093 aesir binary)
# is running; the loaded leg re-checks after the co-runner starts and
# aborts (killing the co-runner) if S-093 appeared -- the co-runner is
# never added on top of a live S-093 run. Machine state is logged at
# leg start and end. Exit 3 = guard-blocked (nothing ran).
set -u
LEG="${1:?usage: j023_run.sh idle|loaded}"
export PATH=/home/volmarr/.pixi/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/home/volmarr/j022/stage
export CUDA_VISIBLE_DEVICES=
M=/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf
BIN=/home/volmarr/j022/test_olmoe_stream_fix
WORK=/home/volmarr/j023
IDS67=$(cat /home/volmarr/j022/prompt_prose_ids.csv)
mkdir -p "$WORK"
OUT="$WORK/run_${LEG}.log"
META="$WORK/run_${LEG}.meta"
CORUNNER_LOG="$WORK/corunner.log"

s093_active() {
  pgrep -f 's026l/(tf_oracle|fr_oracle)' >/dev/null && return 0
  pgrep -f 's093.*aesir|aesir.*s093' >/dev/null && return 0
  return 1
}

state_line() {
  local load tctl memavail
  load=$(cut -d' ' -f1-3 /proc/loadavg)
  tctl=$(sensors 2>/dev/null | grep -i 'Tctl' | awk '{print $2}')
  memavail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  echo "loadavg=$load tctl=$tctl mem_available_kb=$memavail"
}

{
  echo "LEG=$LEG time=$(date -Is)"
  echo "start: $(state_line)"
  if s093_active; then echo "GUARD: S-093 compute process live at leg start"; fi
} > "$META"

if s093_active; then
  echo "GUARD_BLOCKED leg=$LEG reason=s093_live_at_start" | tee -a "$META"
  exit 3
fi

CORUNNER_PID=""
cleanup() {
  if [ -n "$CORUNNER_PID" ]; then
    kill "$CORUNNER_PID" 2>/dev/null
    wait "$CORUNNER_PID" 2>/dev/null
    CORUNNER_PID=""
  fi
}
trap cleanup EXIT

if [ "$LEG" = "loaded" ]; then
  nice -n 0 python3 "$WORK/j023_corunner.py" 4 10 > "$CORUNNER_LOG" 2>&1 &
  CORUNNER_PID=$!
  sleep 5
  if ! kill -0 "$CORUNNER_PID" 2>/dev/null; then
    echo "CORUNNER_FAILED leg=$LEG" | tee -a "$META"
    cat "$CORUNNER_LOG" >> "$META"
    exit 4
  fi
  if s093_active; then
    echo "GUARD_BLOCKED leg=$LEG reason=s093_appeared_after_corunner_start" | tee -a "$META"
    cleanup
    exit 3
  fi
  echo "loaded: $(state_line)" >> "$META"
  echo "corunner_pid=$CORUNNER_PID" >> "$META"
fi

/usr/bin/time -v nice -n 10 "$BIN" "$M" 512 536870912 "$IDS67" 24 > "$OUT" 2> "$WORK/run_${LEG}.time"
RC=$?
echo "RUN_EXIT=$RC leg=$LEG" | tee -a "$META"
grep -E 'Maximum resident|Elapsed \(wall' "$WORK/run_${LEG}.time" >> "$META" 2>/dev/null
echo "end: $(state_line)" >> "$META"
cleanup
if [ "$LEG" = "loaded" ]; then
  if pgrep -f 'j023_corunner' >/dev/null; then
    echo "CORUNNER_STILL_RUNNING" | tee -a "$META"
  else
    echo "corunner_verified_gone" >> "$META"
  fi
  cat "$CORUNNER_LOG" >> "$META"
fi
grep 'Generated IDs' "$OUT" || true
grep -E '^\[CACHE\]|^\[STREAM\]|TIMING' "$OUT" || true
echo "LEG_DONE leg=$LEG rc=$RC"
