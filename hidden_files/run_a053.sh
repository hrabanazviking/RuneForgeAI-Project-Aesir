#!/usr/bin/env bash
# run_a053.sh -- A-053 Z13 storage verification driver (purpleraider).
# Re-runs the existing crash-recovery batteries against state roots on
# the btrfs checkout filesystem (TMPDIR redirected off tmpfs), then the
# full E-MASTER suite via the A-035 fast gate.
set -u
cd "$(dirname "$0")/.." || exit 99
export PATH="$HOME/.pixi/bin:$PATH"
BTRFS_TMP="$PWD/hidden_files/a053_btrfs_tmp"
mkdir -p "$BTRFS_TMP"
echo "filesystems:"; df -T "$PWD" /tmp | cat
pixi run --frozen mojo build --target-accelerator gfx1151 \
  aesir_engine/tests/test_conversation_autosave.mojo \
  -o /tmp/aesir-autosave-probe-a053 || exit 1
TMPDIR="$BTRFS_TMP" python3 scripts/test_conversation_autosave.py \
  --binary /tmp/aesir-autosave-probe-a053 || exit 1
python3 scripts/test_conversation_autosave.py \
  --binary /tmp/aesir-autosave-probe-a053 || exit 1
TMPDIR="$BTRFS_TMP" python3 scripts/test_conversation_library.py || exit 1
scripts/gate_fast.sh || exit 1
echo "A053 DRIVER: PASS"
