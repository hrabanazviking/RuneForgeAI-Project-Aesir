#!/usr/bin/env bash
# bench/run.sh — H161 harness wrapper (runs ON MIMIR).
#
# Pins the cpufreq governor to "performance", pins the benchmark to one
# core with taskset, builds run_bench if needed, runs it, then restores
# the governor to "ondemand". Every C9 measurement goes through this
# wrapper so the pin state is identical every time.
#
# Usage: bench/run.sh --bench <name> --out <name> [run_bench options...]
# Env: PIN_CORE (default 3), MOJO_BIN (default mojo).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN_CORE="${PIN_CORE:-3}"
MOJO_BIN="${MOJO_BIN:-mojo}"

if [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "arm64" ]; then
    echo "run.sh: refusing: not aarch64 ($(uname -m)); C9 measures on Mimir only." >&2
    exit 1
fi

BIN="$ROOT/build/run_bench"
if [ ! -x "$BIN" ]; then
    echo "run.sh: building run_bench..."
    mkdir -p "$ROOT/build"
    (cd "$ROOT" && "$MOJO_BIN" build -I . -o build/run_bench bench/run_bench.mojo)
fi

restore() {
    for p in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
        echo ondemand | sudo tee "$p" > /dev/null 2>&1 || true
    done
    echo "run.sh: governor restored to ondemand"
}
trap restore EXIT

for p in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
    echo performance | sudo tee "$p" > /dev/null
done
echo "run.sh: governor pinned to performance; taskset -c $PIN_CORE"

MOJO_VER="$("$MOJO_BIN" --version 2>/dev/null | head -n 1)"
taskset -c "$PIN_CORE" "$BIN" \
    --root "$ROOT" \
    --mojo-version "$MOJO_VER" \
    --pin "taskset -c $PIN_CORE; cpufreq governor=performance (sudo)" \
    "$@"
