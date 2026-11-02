#!/bin/bash
# J-023 waiter (purplelongship, runs in tmux session "j023wait").
# S-093 (204 road) owns the box: this script waits until the S-093
# driver process AND every S-093 oracle process are gone, then runs
# the idle leg and the loaded leg back-to-back through j023_run.sh
# (whose own guard re-verifies the gap before each leg). Nothing here
# runs a measurement while S-093 is live.
set -u
WORK=/home/volmarr/j023
LOG="$WORK/waiter.log"
echo "WAITER_START $(date -Is)" >> "$LOG"
while true; do
  if ! pgrep -f 's093_driver' >/dev/null \
     && ! pgrep -f 's026l/(tf_oracle|fr_oracle)' >/dev/null; then
    break
  fi
  sleep 20
done
echo "WAITER_GAP $(date -Is) s093 gone; settling 10 s" >> "$LOG"
sleep 10
bash "$WORK/j023_run.sh" idle >> "$LOG" 2>&1
echo "WAITER_IDLE_RC=$?" >> "$LOG"
sleep 5
bash "$WORK/j023_run.sh" loaded >> "$LOG" 2>&1
echo "WAITER_LOADED_RC=$?" >> "$LOG"
echo "WAITER_DONE $(date -Is)" >> "$LOG"
