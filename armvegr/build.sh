#!/usr/bin/env bash
# H021 — ARMVEGR single documented build command + compile gate.
#
# Usage: ./armvegr/build.sh
# Builds the C2 verification binary (which imports the whole armvegr
# package, so a successful build proves the package compiles).
#
# COMPILE GATE: refuses with a clear error on non-AArch64 hosts or when
# NEON/ASIMD is unavailable. Verified on x86_64 (see
# data/armvegr/x86_64_build_failure.txt).
set -euo pipefail

ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo "ARMVEGR BUILD REFUSED: this package targets AArch64+NEON only." >&2
    echo "  host arch: $ARCH (need aarch64)" >&2
    echo "  Build on Mimir (Raspberry Pi 5) or another AArch64 host." >&2
    exit 1
fi
if ! grep -q asimd /proc/cpuinfo 2>/dev/null; then
    echo "ARMVEGR BUILD REFUSED: NEON/ASIMD not detected in /proc/cpuinfo." >&2
    exit 1
fi

MOJO_BIN="${MOJO_BIN:-mojo}"
if ! command -v "$MOJO_BIN" >/dev/null 2>&1; then
    echo "ARMVEGR BUILD REFUSED: mojo not found (tried '$MOJO_BIN')." >&2
    echo "  On Mimir run under: pixi run --manifest-path /home/pi/mojo-dev/pixi.toml $0" >&2
    echo "  or export MOJO_BIN=/usr/local/bin/mojo (the pixi shim)." >&2
    exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p build
"$MOJO_BIN" build -o build/c2_verify tests/c2_verify.mojo
echo "ARMVEGR build OK: build/c2_verify"
