#!/usr/bin/env bash
# Build the probe + independent-display unlock EFIs from pinned upstream source,
# fetch/generate the pinned NVIDIA 610.43.03 firmware assets, and assemble a
# USB payload directory. Nothing is flashed, installed, or written outside OUT.
#
# Requires: git, bun, clang, lld-link (LLVM), python3, and MinGW-w64 headers
# (Debian/Ubuntu: apt install clang lld mingw-w64; bun from https://bun.sh).
set -euo pipefail
UPSTREAM=${UPSTREAM:-https://github.com/craftingmod/rtx30-unlock}
COMMIT=5c076dc4ee7fa369639669fa591ac74d8f6dfcd8
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=${WORK:-$PWD/build-src}
OUT=${OUT:-$PWD/usb-payload}

[ -e "$OUT" ] && { echo "Refusing: $OUT already exists" >&2; exit 2; }
if [ ! -d "$WORK/.git" ]; then git clone "$UPSTREAM" "$WORK"; fi
cd "$WORK"
git checkout -q "$COMMIT"
git apply --check "$HERE/patches/0001-independent-display-runtime-profile.patch"
git apply "$HERE/patches/0001-independent-display-runtime-profile.patch"
cp "$HERE/tools/build-independent.ts" "$HERE/tools/build-probe-linux.ts" tools/
bun install --frozen-lockfile
bun tools/build-probe-linux.ts
bun tools/build-independent.ts
bun run firmware:assets          # downloads + checks pinned NVIDIA inputs, writes build/firmware-assets

mkdir -p "$OUT/EFI/BOOT" "$OUT/STAGE" "$OUT/RTX30-PROBE" "$OUT/RTX-UNLOCK/ASSETS"
cp build/probe/BOOTX64.EFI            "$OUT/EFI/BOOT/BOOTX64.EFI"   # stage 1 = read-only probe
cp build/probe/BOOTX64.EFI            "$OUT/STAGE/PROBE.EFI"
cp build/efi-independent/BOOTX64.EFI  "$OUT/STAGE/UNLOCK.EFI"       # stage 2 = unlock
cp build/firmware-assets/*.bin        "$OUT/RTX-UNLOCK/ASSETS/"
cp build/firmware-assets/NVIDIA-LICENSE "$OUT/RTX-UNLOCK/NVIDIA-LICENSE"
cp LICENSE "$OUT/RTX-UNLOCK/LICENSE-GPL-2.0.txt"

cd "$OUT"
sha256sum -c "$HERE/SHA256SUMS.expected"
echo "USB payload ready in $OUT (PROFILE.BIN still missing: run the probe first)."
