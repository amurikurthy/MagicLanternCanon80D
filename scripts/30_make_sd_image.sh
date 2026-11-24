#!/usr/bin/env bash
# Build a bootable ML SD card image for QEMU WITHOUT libguestfs.
#
# Upstream `make disk_image` uses guestmount, which needs a host kernel + KVM
# and fails in containers. The base image shipped in-tree
# (platform/sd.qcow2.xz) is ALREADY a bootable ML card; we just need to drop a
# fresh autoexec.bin + ML/ into its FAT partition. We do that with mtools
# (no mounting), converting qcow2<->raw with qemu-img.
#
# Output: $PLATFORM_DIR/build/sd.qcow2 and cf.qcow2 (what run_qemu/40_boot use).
set -euo pipefail

WORKROOT="${WORKROOT:-/home/user/src}"
ML_DIR="$WORKROOT/magiclantern_simplified"
PLATFORM_DIR="$ML_DIR/platform/80D.103"
ZIP="$PLATFORM_DIR/build/magiclantern.zip"
BASE_XZ="$ML_DIR/platform/sd.qcow2.xz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$ZIP" ] || { echo "!! $ZIP missing — run 10_build_ml.sh first"; exit 1; }

echo ">> decompress base image and convert to raw ..."
xz -dc "$BASE_XZ" > "$TMP/base.qcow2"
qemu-img convert -O raw "$TMP/base.qcow2" "$TMP/sd.raw"

echo ">> locate FAT partition offset ..."
START_SECTOR="$(fdisk -l "$TMP/sd.raw" | awk '/sd\.raw1|\.raw1/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/){print $i; exit}}')"
: "${START_SECTOR:=99}"
OFFSET=$(( START_SECTOR * 512 ))
IMG="$TMP/sd.raw@@$OFFSET"
echo "   partition starts at sector $START_SECTOR (offset $OFFSET)"

echo ">> extract fresh ML build ..."
rm -rf "$TMP/ml"; mkdir -p "$TMP/ml"
unzip -q "$ZIP" -d "$TMP/ml"

echo ">> write autoexec.bin + ML/ into the FAT image (mtools) ..."
mdel     -i "$IMG" ::/autoexec.bin 2>/dev/null || true
mdeltree -i "$IMG" ::/ML           2>/dev/null || true
mcopy -s -i "$IMG" "$TMP/ml/autoexec.bin" ::
mcopy -s -i "$IMG" "$TMP/ml/ML" ::
echo "   image root now:"; mdir -i "$IMG" :: | sed -n '3,12p'

echo ">> convert back to qcow2 (sd + cf) ..."
mkdir -p "$PLATFORM_DIR/build"
qemu-img convert -O qcow2 "$TMP/sd.raw" "$PLATFORM_DIR/build/sd.qcow2"
cp "$PLATFORM_DIR/build/sd.qcow2" "$PLATFORM_DIR/build/cf.qcow2"

echo ">> done: $PLATFORM_DIR/build/sd.qcow2"
