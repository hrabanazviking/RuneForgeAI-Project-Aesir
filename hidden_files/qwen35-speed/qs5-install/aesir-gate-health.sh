#!/usr/bin/env bash
# QS-5 watchdog health check for aesir-gate.service.
# Curls /health with the service key (read at runtime from the
# key file; the key is never logged or echoed). Counts
# consecutive failures in a state file; after 3 consecutive
# failures it restarts the unit. Every check and every action
# is logged to the journal (logger, tag aesir-gate-watchdog)
# and appended to the watchdog log file in the campaign folder.
set -u
KEY_FILE=/home/volmarr/.config/aesir/service.key
STATE_DIR=/home/volmarr/aesir-hipserve/hidden_files/qwen35-speed
STATE=$STATE_DIR/watchdog-state.txt
LOG=$STATE_DIR/watchdog.log
UNIT=aesir-gate.service
URL=http://127.0.0.1:18434/health
ts=$(date -Is)
key=""
if [ -r "$KEY_FILE" ]; then
  key=$(cat "$KEY_FILE")
fi
fails=0
if [ -f "$STATE" ]; then
  fails=$(cat "$STATE" 2>/dev/null || echo 0)
fi
case "$fails" in
  ''|*[!0-9]*) fails=0 ;;
esac
ok=0
if systemctl is-active --quiet "$UNIT" && [ -n "$key" ]; then
  if curl -sf -m 15 -H "Authorization: Bearer $key" "$URL" 2>/dev/null | grep -q '"status":"ready"'; then
    ok=1
  fi
fi
if [ "$ok" -eq 1 ]; then
  if [ "$fails" != "0" ]; then
    echo "$ts RECOVERED health ready after $fails consecutive failures" >> "$LOG"
    logger -t aesir-gate-watchdog "health ready again after $fails consecutive failures"
  fi
  echo 0 > "$STATE"
  echo "$ts OK fails=0" >> "$LOG"
else
  fails=$((fails + 1))
  echo "$fails" > "$STATE"
  echo "$ts FAIL consecutive=$fails" >> "$LOG"
  logger -t aesir-gate-watchdog "health check FAILED ($fails consecutive)"
  if [ "$fails" -ge 3 ]; then
    echo "$ts ACTION restarting $UNIT after $fails consecutive failures" >> "$LOG"
    logger -t aesir-gate-watchdog "restarting $UNIT after $fails consecutive health failures"
    systemctl reset-failed "$UNIT" 2>/dev/null || true
    systemctl restart "$UNIT" 2>/dev/null || systemctl start "$UNIT" 2>/dev/null || true
    echo 0 > "$STATE"
    echo "$ts ACTION restart issued for $UNIT" >> "$LOG"
  fi
fi
exit 0
