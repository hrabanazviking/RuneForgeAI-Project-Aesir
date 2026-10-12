#!/usr/bin/env bash
# Build only AESIR's direct Hailo GenAI backend and canonical command line.
set -euo pipefail

aesir_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
aesir_output="${1:-$aesir_root/work}"
aesir_cxx="${AESIR_HAILO_CXX:-g++}"
aesir_mojo="${AESIR_HAILO_MOJO:-mojo}"
if (( $# > 1 )); then
    printf 'Usage: %s [output-directory]\n' "$0" >&2
    exit 2
fi
command -v "$aesir_cxx" >/dev/null
command -v "$aesir_mojo" >/dev/null
mkdir -p -- "$aesir_output"
aesir_output="$(cd -- "$aesir_output" && pwd)"
# Keep a failed build separate from an existing executable/library pair.
# Generations are retained locally; only a successful pair is published.
aesir_stage="$(mktemp -d "$aesir_output/.hailo-build.XXXXXXXX")"
"$aesir_cxx" -std=c++17 -Wall -Wextra -Werror -fPIC -shared \
    "$aesir_root/aesir_engine/hailo10h_bridge.cpp" -lhailort -lcrypto -pthread \
    -o "$aesir_stage/libaesir_hailo10h.so"
MODULAR_CACHE_DIR="${MODULAR_CACHE_DIR:-$aesir_output/mojo-cache}" \
    "$aesir_mojo" build -I "$aesir_root/aesir_engine" \
    -Xlinker -L"$aesir_stage" -Xlinker -laesir_hailo10h \
    -Xlinker -rpath -Xlinker '$ORIGIN' \
    "$aesir_root/aesir_engine/main.mojo" -o "$aesir_stage/aesir"
ln -s -- "$(basename -- "$aesir_stage")/aesir" "$aesir_output/.aesir-next-$(basename -- "$aesir_stage")"
ln -s -- "$(basename -- "$aesir_stage")/libaesir_hailo10h.so" "$aesir_output/.hailo-library-next-$(basename -- "$aesir_stage")"
mv -Tf -- "$aesir_output/.hailo-library-next-$(basename -- "$aesir_stage")" "$aesir_output/libaesir_hailo10h.so"
mv -Tf -- "$aesir_output/.aesir-next-$(basename -- "$aesir_stage")" "$aesir_output/aesir"
printf 'Built direct Hailo-10H AESIR: %s/aesir\n' "$aesir_output"
