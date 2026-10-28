#!/usr/bin/env bash
# Build libaesir_image.so: the PNG/JPEG decode shim used by
# loader/image_prep.mojo (dlopen'd lazily; AESIR_IMAGE_LIB or the
# loader search path locates it at runtime). Native system libraries
# only (libpng + libjpeg with their system headers).
set -euo pipefail

aesir_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
aesir_output="${1:-$aesir_root/work}"
aesir_cc="${AESIR_IMAGE_CC:-cc}"
if (( $# > 1 )); then
    printf 'Usage: %s [output-directory]\n' "$0" >&2
    exit 2
fi
command -v "$aesir_cc" >/dev/null
mkdir -p -- "$aesir_output"
"$aesir_cc" -O2 -fPIC -shared -Wall -Wextra \
    -o "$aesir_output/libaesir_image.so" \
    "$aesir_root/aesir_engine/image_decode.c" -lpng16 -ljpeg
printf 'Built %s/libaesir_image.so\n' "$aesir_output"
