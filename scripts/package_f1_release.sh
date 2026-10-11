#!/usr/bin/env bash
# scripts/package_f1_release.sh — H190 ARM64 release packaging.
#
# Assembles the F1 CPU inference release: the pure-Mojo production
# binary plus its data files, installable on a clean Pi 5 with NO
# Python present. The package contains no .py files, no HEF files,
# no firmware blobs (verified by extension scan before sealing).
#
# Usage: ./scripts/package_f1_release.sh --version <ver> --out <dir>
# Output: <out>/aesir-f1-<ver>-aarch64.tar.gz + .sha256
#
# Layout inside the tarball:
#   aesir-f1-<ver>/
#     bin/f1_infer            (rpath $ORIGIN/../lib — self-contained)
#     lib/                    (Mojo toolchain runtime libs the binary
#                              links against, bundled unmodified; the
#                              binary does NOT run without them — proven
#                              by the H190 container test)
#     config/f1_config.json
#     share/tokenizer/tinyllama_tokenizer.model
#     share/doc/RUNBOOK.md  share/doc/RELEASE_NOTES.md
#     THIRD_PARTY_NOTICES.md  MANIFEST.txt
#
# Build-host requirement: patchelf (Debian: apt-get install patchelf).
# The script FAILS CLOSED if patchelf is missing.
set -euo pipefail

VERSION=""
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done
[ -n "$VERSION" ] && [ -n "$OUT" ] || { echo "usage: $0 --version <ver> --out <dir>" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$OUT/stage/aesir-f1-$VERSION"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/config" "$STAGE/share/tokenizer" "$STAGE/share/doc" "$OUT"

echo "H190: building release binary from $(git -C "$HERE" rev-parse --short HEAD)"
mkdir -p "$HERE/build"
mojo build -I "$HERE" -o "$HERE/build/f1_infer" "$HERE/armvegr/f1_infer.mojo"

cp "$HERE/build/f1_infer" "$STAGE/bin/"

# H190 (gauntlet-found defect, fixed in-domain): the Mojo binary links
# against toolchain runtime libraries (libKGENCompilerRTShared,
# libMSupportGlobals, libAsyncRTRuntimeGlobals, libstdc++, libgcc_s)
# that live in the build host's Mojo installation. A bare binary copy
# does NOT run on a clean machine (proven by the H190 container test:
# "libKGENCompilerRTShared.so: cannot open shared object file").
# Bundle every toolchain-provided library the binary needs and point
# the binary's rpath at the bundled lib/ via $ORIGIN.
command -v patchelf >/dev/null 2>&1 || {
  echo "H190 FAIL: patchelf not found on build host (apt-get install patchelf)" >&2
  exit 1
}
mkdir -p "$STAGE/lib"
KGEN_PATH="$(ldd "$HERE/build/f1_infer" | awk '/libKGENCompilerRTShared/ {print $3}')"
[ -n "$KGEN_PATH" ] || { echo "H190 FAIL: cannot locate libKGENCompilerRTShared via ldd" >&2; exit 1; }
TOOLCHAIN_LIB_DIR="$(dirname "$KGEN_PATH")"
echo "H190: bundling toolchain runtime libs from $TOOLCHAIN_LIB_DIR"
ldd "$HERE/build/f1_infer" | awk '{print $3}' | grep "^$TOOLCHAIN_LIB_DIR/" | sort -u | while read -r so; do
  cp -L "$so" "$STAGE/lib/"
  echo "H190:   bundled $(basename "$so")"
done
patchelf --set-rpath '$ORIGIN/../lib' "$STAGE/bin/f1_infer"
# Fail closed if the staged binary still has unresolved libraries.
if ldd "$STAGE/bin/f1_infer" | grep -q "not found"; then
  echo "H190 FAIL: staged binary has unresolved libraries:" >&2
  ldd "$STAGE/bin/f1_infer" | grep "not found" >&2
  exit 1
fi
echo "H190: staged binary self-contained (ldd clean, rpath \$ORIGIN/../lib)"
cp "$HERE/data/fallback/f1_config.json" "$STAGE/config/"
cp "$HERE/data/gauntlet/storm_config.json" "$STAGE/config/" 2>/dev/null || true
cp "$HERE/data/armvegr/tinyllama_tokenizer.model" "$STAGE/share/tokenizer/"
cp "$HERE/docs/gauntlet/RUNBOOK.md" "$STAGE/share/doc/" 2>/dev/null || true
cp "$HERE/docs/gauntlet/RELEASE_NOTES.md" "$STAGE/share/doc/" 2>/dev/null || true
cp "$HERE/docs/vordr/vordr-watchdog.service" "$STAGE/share/doc/" 2>/dev/null || true
cp "$HERE/data/gauntlet/canary.json" "$STAGE/share/doc/" 2>/dev/null || true
cp "$HERE/THIRD_PARTY_NOTICES.md" "$STAGE/"

# H190: the package must contain no .py, no HEF, no firmware blobs.
echo "H190: scanning for forbidden artifacts..."
if find "$STAGE" \( -name "*.py" -o -name "*.pyc" -o -name "*.hef" -o -name "*.bin" -o -name "*.fw" \) | grep -q .; then
  echo "H190 FAIL: forbidden artifact in package:" >&2
  find "$STAGE" \( -name "*.py" -o -name "*.pyc" -o -name "*.hef" -o -name "*.bin" -o -name "*.fw" \) >&2
  exit 1
fi
echo "H190: artifact scan clean (no .py/.pyc/.hef/.bin/.fw)"

# MANIFEST.txt: sha256 of every shipped file.
(cd "$STAGE" && find . -type f ! -name MANIFEST.txt | sort | xargs sha256sum > MANIFEST.txt)

TARBALL="$OUT/aesir-f1-$VERSION-aarch64.tar.gz"
tar -czf "$TARBALL" -C "$OUT/stage" "aesir-f1-$VERSION"
sha256sum "$TARBALL" > "$TARBALL.sha256"
echo "H190: package sealed: $TARBALL"
cat "$TARBALL.sha256"
