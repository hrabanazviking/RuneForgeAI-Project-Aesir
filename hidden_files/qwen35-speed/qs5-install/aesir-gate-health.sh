#!/bin/bash
# QS-5 watchdog check: is aesir-gate alive AND answering?
# The key is read at runtime and never logged.
# Logs every check to the journal (tag aesir-gate-watchdog)
# and to watchdog.log beside this record. After 3
# consecutive failures it restarts the unit and logs the
# ACTION in both places.
#
# BUSY GUARD (v2, learned in the QS-5.4 soak): the serve
# is single-concurrency with a 30 s queue timeout, so
# during one long prefill/generation a /health request
# can wait in queue past its timeout and fail while the
# serve is perfectly healthy. A health failure therefore
# only counts toward a restart when the serve process is
# NOT demonstrably working: if its CPU time advanced by
# >= 30 s since the previous check, the failure is logged
# as BUSY and the counter does not move. Process death is
# already covered by Restart=on-failure; this watchdog
# exists for the wedged-but-alive case (idle CPU +
# unresponsive + 3 consecutive checks -> restart).
KEY_FILE=/home/volmarr/.config/aesir/service.key
STATE_DIR=/home/volmarr/aesir-hipserve/hidden_files/qwen35-speed
STATE=$STATE_DIR/watchdog-state.txt
CPUSTATE=$STATE_DIR/watchdog-cpu.txt
LOGF=$STATE_DIR/watchdog.log
UNIT=aesir-gate.service
URL=http://127.0.0.1:18434/health
TS=$(date -Is)

log() {
  echo "$TS $1" >> "$LOGF"
  logger -t aesir-gate-watchdog -- "$1"
}

fails=0
[ -f "$STATE" ] && fails=$(cat "$STATE" 2>/dev/null || echo 0)
case "$fails" in *[!0-9]*) fails=0 ;; esac

ok=0
if systemctl is-active --quiet "$UNIT"; then
  KEY=$(cat "$KEY_FILE" 2>/dev/null)
  if [ -n "$KEY" ]; then
    BODY=$(curl -s -m 15 -H "Authorization: Bearer $KEY" "$URL" 2>/dev/null)
    echo "$BODY" | grep -q '"status":"ready"' && ok=1
    echo "$BODY" | grep -q '"status": "ready"' && ok=1
  fi
fi

# CPU time of the serve process (utime+stime, jiffies).
cpu_now=0
PID=$(systemctl show "$UNIT" -p MainPID --value 2>/dev/null)
if [ -n "$PID" ] && [ "$PID" != "0" ] && [ -r "/proc/$PID/stat" ]; then
  cpu_now=$(awk '{print $14+$15}' "/proc/$PID/stat" 2>/dev/null || echo 0)
fi
cpu_prev=0
[ -f "$CPUSTATE" ] && cpu_prev=$(cat "$CPUSTATE" 2>/dev/null || echo 0)
case "$cpu_prev" in *[!0-9]*) cpu_prev=0 ;; esac
echo "$cpu_now" > "$CPUSTATE"
cpu_delta=$((cpu_now - cpu_prev))
[ "$cpu_delta" -lt 0 ] && cpu_delta=0
HZ=100

if [ "$ok" = "1" ]; then
  echo 0 > "$STATE"
  log "OK fails=0"
  exit 0
fi

# Busy guard: >= 30 s of CPU since the last check means
# the engine is working (a long request), not wedged.
if [ "$cpu_delta" -ge $((30 * HZ)) ]; then
  log "BUSY health-unreachable but serve CPU advanced ${cpu_delta} jiffies; not counting"
  exit 0
fi

fails=$((fails + 1))
echo "$fails" > "$STATE"
log "FAIL consecutive=$fails cpu_delta=${cpu_delta}"
if [ "$fails" -ge 3 ]; then
  log "ACTION restarting $UNIT after 3 consecutive idle failures"
  systemctl reset-failed "$UNIT" 2>/dev/null
  systemctl restart "$UNIT"
  echo 0 > "$STATE"
  log "ACTION restart issued"
fi
exit 0
