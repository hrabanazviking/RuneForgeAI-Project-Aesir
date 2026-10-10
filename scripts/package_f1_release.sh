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
#     bin/f1_infer
#     config/f1_config.json
#     share/tokenizer/tinyllama_tokenizer.model
#     share/doc/RUNBOOK.md  share/doc/RELEASE_NOTES.md
#     THIRD_PARTY_NOTICES.md  MANIFEST.txt
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
