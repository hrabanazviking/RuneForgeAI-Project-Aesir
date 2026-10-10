#!/usr/bin/env bash
# VÖRÐR-supervised inference process (H146).
#
# The long-running F1 inference process the watchdog supervises in
# production: generates text forever (the F1 engine is a single-shot
# CLI, so the supervised process is this loop). Exits nonzero on
# repeated child failure so the watchdog's restart policy engages.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROMPTS=(
  "The völva watches the wyrd unfold."
  "Firelight dances on the carved runes."
  "The sea-road calls the wanderer home."
)
i=0
fails=0
while true; do
  p="${PROMPTS[$((i % 3))]}"
  if "$HERE/f1_infer" --config "$HERE/data/fallback/f1_config.json" \
      --prompt "$p" --max-new-tokens 24 --seed "$i" \
      --out "$HERE/vordr-supervised-last.json" >/dev/null 2>&1; then
    fails=0
  else
    fails=$((fails + 1))
    echo "vordr_supervised: f1_infer failed ($fails in a row)" >&2
    if [ "$fails" -ge 5 ]; then
      echo "vordr_supervised: 5 consecutive failures, exiting for watchdog" >&2
      exit 3
    fi
    sleep 5
  fi
  i=$((i + 1))
done
