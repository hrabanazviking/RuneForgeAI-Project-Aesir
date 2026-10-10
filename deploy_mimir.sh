#!/usr/bin/env bash
# deploy_mimir.sh — H191 deployment script for Mimir.
#
# One command from build host to running service. RUNS ON MIMIR
# (the deployment target); invoke it via the operator's device path
# (Tailscale/device.invoke) or over SSH.
#
# Prerequisites (documented):
#   - the release tarball aesir-f1-<ver>-aarch64.tar.gz + .sha256
#     (built by scripts/package_f1_release.sh from the tagged commit)
#   - the reference model at /home/pi/models/tinyllama/
#     tinyllama-1.1b-chat-v1.0.Q4_0.gguf (sha256 verified)
#   - for the systemd watchdog unit: sudo, or `loginctl enable-linger pi`
#     for the user-unit fallback (the script picks what is available and
#     records the choice)
#
# What it does:
#   1. verifies tarball sha256 (aborts on mismatch, before touching anything)
#   2. extracts to /home/pi/aesir-f1-<ver>/
#   3. backs up any existing operator config with a timestamp (never
#      overwrites operator config without backup)
#   4. verifies the reference model sha256
#   5. installs + enables the vordr watchdog supervisor unit
#      (systemd system unit with sudo, else user unit)
#   6. asserts the `driver` symlink -> the new release
#      (NO-GO branch: no kernel driver exists; the operator-approved
#      equivalent is the stable production-release symlink
#      /home/pi/aesir-driver)
#   7. smoke inference: the canary prompt; the first 10 generated token
#      ids must equal data/gauntlet/canary.json exactly
#
# Usage: ./deploy_mimir.sh --package <tarball> --version <ver>
set -euo pipefail

PACKAGE=""
VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --package) PACKAGE="$2"; shift 2;;
    --version) VERSION="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done
[ -n "$PACKAGE" ] && [ -n "$VERSION" ] || { echo "usage: $0 --package <tarball> --version <ver>" >&2; exit 1; }

PROD_BASE="/home/pi"
RELDIR="$PROD_BASE/aesir-f1-$VERSION"
MODEL="/home/pi/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_0.gguf"
MODEL_SHA="da3087fb14aede55fde6eb81a0e55e886810e43509ec82ecdc7aa5d62a03b556"
CANARY="$RELDIR/share/doc/canary.json"
[ -f "$CANARY" ] || CANARY="$(dirname "$0")/../data/gauntlet/canary.json"

echo "=== H191 deploy: aesir-f1-$VERSION ==="

# 1. Checksum verification FIRST — abort before touching anything.
echo "-- verifying package checksum"
(cd "$(dirname "$PACKAGE")" && sha256sum -c "$(basename "$PACKAGE").sha256")
echo "   checksum OK"

# 2. Extract.
echo "-- extracting to $RELDIR"
rm -rf "$RELDIR"
mkdir -p "$RELDIR"
tar -xzf "$PACKAGE" -C "$RELDIR" --strip-components=1

# 3. Operator config backup (never overwrite without backup).
OPCFG="$PROD_BASE/.aesir-operator.conf"
if [ -f "$OPCFG" ]; then
  BAK="$OPCFG.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$OPCFG" "$BAK"
  echo "-- operator config backed up to $BAK"
else
  echo "-- no existing operator config (nothing to back up)"
fi

# 4. Reference model verification.
echo "-- verifying reference model"
echo "$MODEL_SHA  $MODEL" | sha256sum -c -
echo "   model OK"

# 5. Watchdog supervisor unit.
UNIT_SRC="$RELDIR/share/doc/vordr-watchdog.service"
UNIT_DST="/etc/systemd/system/vordr-watchdog.service"
MODE=""
if [ -f "$UNIT_SRC" ]; then
  if sudo -n true 2>/dev/null; then
    sudo cp "$UNIT_SRC" "$UNIT_DST"
    sudo sed -i "s#/home/pi/mimisbrunnr_c8#$RELDIR#g" "$UNIT_DST"
    sudo systemctl daemon-reload
    sudo systemctl enable --now vordr-watchdog
    MODE="systemd-system"
  else
    mkdir -p "$HOME/.config/systemd/user"
    cp "$UNIT_SRC" "$HOME/.config/systemd/user/vordr-watchdog.service"
    sed -i "s#/home/pi/mimisbrunnr_c8#$RELDIR#g" "$HOME/.config/systemd/user/vordr-watchdog.service"
    systemctl --user daemon-reload || true
    systemctl --user enable --now vordr-watchdog || true
    MODE="systemd-user"
  fi
  echo "-- watchdog supervisor installed (mode: $MODE)"
else
  echo "-- WARNING: unit file not in package; supervisor install skipped (recorded)"
  MODE="skipped-no-unit-in-package"
fi
echo "$MODE" > "$RELDIR/WATCHDOG_MODE.txt"

# 6. The `driver` symlink (NO-GO equivalent: stable production release path).
ln -sfn "$RELDIR" "$PROD_BASE/aesir-driver"
TGT="$(readlink "$PROD_BASE/aesir-driver")"
[ "$TGT" = "$RELDIR" ] || { echo "H191 FAIL: driver symlink wrong: $TGT" >&2; exit 1; }
echo "-- driver symlink asserted: $PROD_BASE/aesir-driver -> $TGT"

# 7. Smoke inference: canary prompt, first-10 GENERATED token ids must match exactly.
echo "-- smoke inference (canary)"
PROMPT="$(python3 -c "import json;print(json.load(open('$CANARY'))['prompt'])")"
SEED="$(python3 -c "import json;print(json.load(open('$CANARY'))['seed'])")"
NPT="$(python3 -c "import json;print(json.load(open('$CANARY'))['prompt_tokens'])")"
EXPECT="$(python3 -c "import json;print(' '.join(map(str,json.load(open('$CANARY'))['expected_first_10_generated_ids'])))")"
GOT="$("$RELDIR/bin/f1_infer" --config "$RELDIR/config/storm_config.json" \
  --prompt "$PROMPT" --max-new-tokens 24 --seed "$SEED" \
  | python3 -c "import json,sys,re; d=json.load(open('$CANARY')); m=re.search(r'\"generated_ids\":\s*\[([0-9,\s]+)\]',sys.stdin.read()); ids=[x.strip() for x in m.group(1).split(',')]; print(' '.join(ids[d['prompt_tokens']:d['prompt_tokens']+10]))")"
if [ "$GOT" = "$EXPECT" ]; then
  echo "-- canary PASS: first-10 ids match"
else
  echo "H191 FAIL: canary mismatch" >&2
  echo "  expected: $EXPECT" >&2
  echo "  got:      $GOT" >&2
  exit 1
fi

echo "=== H191 deploy COMPLETE: $RELDIR serving (watchdog: $MODE) ==="
