#!/bin/bash
# Build the engine's Metal kernels for iOS, mirroring upstream
# engine/build.sh's metallib step but for the iphoneos SDK.
#
# Two flags are load-bearing and must not be dropped (upstream
# build.sh, RFC-014 §5.1 trap 1):
#   -fmetal-math-mode=safe
#   -fmetal-math-fp32-functions=precise
# Xcode's default fast math drifts exp/fma by up to 1.1e-5, past the
# engine's float32 bar, and the engine refuses to start if it detects it.
#
# Requires: Xcode command-line tools on a Mac (xcrun), or a macOS
# GitHub Actions runner. This script does NOT run on Linux/Windows.
set -euo pipefail
cd "$(dirname "$0")/.."

ENGINE="${ENGINE:-upstream/engine}"
OUT_DIR="SpektraLab-iPad/Resources/engine"
IOS_MIN="${IOS_MIN:-17.0}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

shopt -s nullglob
airs=()
for m in "$ENGINE"/src/shaders/*.metal; do
  base="$(basename "$m" .metal)"
  echo "metal (iOS $IOS_MIN, safe math): $base"
  xcrun -sdk iphoneos metal \
    -fmetal-math-mode=safe \
    -fmetal-math-fp32-functions=precise \
    -mios-version-min="$IOS_MIN" \
    -Werror -c "$m" -o "$TMP/$base.air"
  airs+=("$TMP/$base.air")
done
shopt -u nullglob

if [ "${#airs[@]}" -eq 0 ]; then
  echo "No .metal shaders found under $ENGINE/src/shaders — did setup.sh clone upstream?" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
xcrun -sdk iphoneos metallib "${airs[@]}" -o "$OUT_DIR/spektrafilm.metallib"
echo "metallib -> $OUT_DIR/spektrafilm.metallib"
echo "Check the target stamp before shipping a build:"
echo "  xcrun -sdk iphoneos metal-readobj --file-headers $OUT_DIR/spektrafilm.metallib | grep -i platform"
