#!/usr/bin/env bash
# Safe, reviewable Lumi-vendor patcher for GSI / custom-kernel pairing on the A31.
# It NEVER touches the source image: it works on a COPY and writes a new file.
# Run in a Linux env with root (loop mount) + e2fsprogs. Keep a stock vendor backup regardless.
#
#   ./patch-vendor.sh SRC.img OUT.img [--strip-modules] [--disable-system-avb] [--add-gsi-keys DIR]
#
#   --strip-modules       comment out /lib/modules/modules.load (stock 4.14 .ko won't load on a
#                         custom kernel). Use ONLY when flashing this vendor with a custom kernel.
#   --disable-system-avb  drop the avb flags from the /system fstab line so any GSI mounts without
#                         matching an avbpubkey (you still flash with vbmeta disabled).
#   --add-gsi-keys DIR    copy *.avbpubkey from DIR into /avb and append them to the system line's
#                         avb_keys (to accept newer GSIs with verification ON).
#
# With no edit flag it only PRINTS the current state (dry run) and copies SRC->OUT unchanged.
set -euo pipefail

SRC=${1:?source vendor .img}; OUT=${2:?output .img}; shift 2 || true
STRIP=0; NOAVB=0; KEYS=""
while [ $# -gt 0 ]; do case "$1" in
  --strip-modules) STRIP=1 ;;
  --disable-system-avb) NOAVB=1 ;;
  --add-gsi-keys) KEYS=$2; shift ;;
  *) echo "unknown arg $1"; exit 2 ;;
esac; shift; done

[ "$(id -u)" = 0 ] || { echo "run as root (loop mount needs it)"; exit 1; }
command -v e2fsck >/dev/null || { echo "need e2fsprogs"; exit 1; }

echo ">> copy (source stays untouched)"; cp --reflink=auto "$SRC" "$OUT"
M=$(mktemp -d)
echo ">> fsck"; e2fsck -fy "$OUT" || true
echo ">> mount rw"; mount -o rw,loop "$OUT" "$M"
trap 'umount "$M" 2>/dev/null; rmdir "$M" 2>/dev/null' EXIT

FSTAB="$M/etc/fstab.mt6768"
echo "== current system fstab line =="; grep -E '^system ' "$FSTAB" || true
echo "== modules.load =="; sed -n '1,20p' "$M/lib/modules/modules.load" 2>/dev/null || true

if [ "$STRIP" = 1 ] && [ -f "$M/lib/modules/modules.load" ]; then
  echo ">> stripping stock modules.load (backup .orig kept)"
  cp "$M/lib/modules/modules.load" "$M/lib/modules/modules.load.orig"
  sed -i 's/^/# custom-kernel: /' "$M/lib/modules/modules.load"
fi

if [ "$NOAVB" = 1 ]; then
  echo ">> removing avb flags from the system line"
  cp "$FSTAB" "$FSTAB.orig"
  # drop avb=...,avb_keys=... tokens from the system mount options
  sed -i -E '/^system /{s/,?avb[^ ,]*//g; s/,?avb_keys=[^ ]*//g}' "$FSTAB"
  grep -E '^system ' "$FSTAB"
fi

if [ -n "$KEYS" ]; then
  echo ">> adding GSI avbpubkeys from $KEYS"
  mkdir -p "$M/avb"
  add=""
  for k in "$KEYS"/*.avbpubkey; do
    [ -e "$k" ] || continue
    cp "$k" "$M/avb/"; add="$add:/avb/$(basename "$k")"
  done
  [ -n "$add" ] && sed -i -E "/^system /s#(avb_keys=[^ ]*)#\\1${add}#" "$FSTAB"
  grep -E '^system ' "$FSTAB"
fi

sync; umount "$M"; trap - EXIT; rmdir "$M"
echo ">> fsck final"; e2fsck -fy "$OUT" || true
echo ">> done: $OUT  ($(du -h "$OUT" | cut -f1))"
echo ">> KEEP a stock vendor backup. Test with ONE flash; restore stock if it does not boot."
