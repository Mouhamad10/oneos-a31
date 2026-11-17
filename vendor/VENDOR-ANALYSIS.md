# Lumi vendor analysis (vendor_a31_lumi_patched_safe.img)

Extracted from the image (ext4, 754 MB, label `vendor`) via `debugfs` — read-only, nothing modified.

## Identity
- Device **SM-A315G** (A31), board **mt6768**.
- Fingerprint `samsung/a31nsxx/a31:12/SP1A.210812.016/A315GXXU5DXJ1:user/release-keys`.
- **Android 12**, `ro.vendor.build.version.sdk=31`, **`ro.vndk.version=31`**, security patch **2022-03-05**.
- API levels: `ro.product.first_api_level=29` (launched on A10), `ro.board.first_api_level=30`.

## VINTF / Treble
- `manifest.xml` is `type="device"` **`target-level="4"`** → FCM **Android 10 (Q)** compatibility target.
- `compatibility_matrix.xml` present (device matrix, small).
- HALs are mostly **HIDL** (audio @7.0, graphics @4.0 mediatek, camera provider @4.0, gnss @2.1,
  fingerprint trustonic, thermal @2.0, mtkpower @1.2, bluetooth.audio @2.2…). Full MTK + Samsung set
  for MT6768 (`audio.primary.mt6768`, `camera.mt6768`, `hwcomposer.mt6768`, `vulkan.mt6768`, `lights.mt6768`).

## fstab (fstab.mt6768) — the important part for GSIs
- `system/vendor/product/odm` = logical ext4 **ro + AVB**, first-stage mount.
- **The `system` line already lists GSI AVB keys:**
  `avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey`
  → the vendor **already accepts Android 10/11/12 (Q/R/S) GSIs** with verification ON.
- `/data` = **f2fs**, `inlinecrypt`, `fileencryption=aes-256-xts`, Samsung SDP (`/keydata`, `/keyrefuge`).
- zram: `fstab.ramplus` (2 GB) and `fstab.enableswap` (55%).

## Shipped kernel modules (built for stock 4.14 — will NOT load on a new kernel)
`bt_drv_connac1x, connfem, fmradio_drv_mt6631, fpsgo, gps_drv, met, udc_lib, wlan_drv_gen4m,
wmt_chrdev_wifi, wmt_drv` (+ modules.load/dep/alias). When pairing this vendor with a **custom** kernel,
the stock `modules.load` / vendor `insmod` lines must be dropped (the new kernel builds these in or
provides its own).

## SELinux
Standard vendor sepolicy: `plat_pub_versioned.cil`, `vendor_file_contexts`, `vendor_property_contexts`,
`vendor_mac_permissions.xml`, `vendor_hwservice_contexts`. **No permissive here** — permissive for
A14+ GSIs is a **kernel/cmdline** setting (`androidboot.selinux=permissive`), not a vendor edit.

## What this vendor can and cannot host
| GSI Android version | Status on this vendor |
|---|---|
| 10 / 11 / 12 (Q/R/S) | ✅ cleanly — AVB keys present, target-level Q, HIDL HALs |
| 13 (T) | ✅ generally works on an A12/VNDK31 vendor |
| 14 / 15 (U/V) | ⚠️ needs SELinux-permissive (kernel) + VINTF tolerance; flaky |
| 16 / 17 | ❌ not a vendor-XML fix — VNDK 31 + target-level + permissive gate it → **kernel track** |

**Bottom line:** the Lumi vendor is already GSI-capable up to ~A13. Making OneOS run **A16/17** GSIs is
primarily the **kernel modernization** job (5.10 GKI / fixed 4.19), not editing this vendor. See
[`../docs/DEVICE-A31.md`](../docs/DEVICE-A31.md) and the a31-nethunter ROADMAP (Phase 7).

## Safe, useful vendor tweaks (see patch-vendor.sh)
1. **Custom-kernel pairing:** strip the stock `modules.load` entries / vendor `insmod` lines (the 10
   modules above won't load on a new kernel).
2. **Newer GSIs with verification ON:** add `t-gsi`/`u-gsi`/`v-gsi` avbpubkeys to `/avb` and to the
   `system` line's `avb_keys` (public AOSP keys). *Or* simply flash GSIs with vbmeta disabled
   (`--disable-verification`), which bypasses this entirely.
3. Do **not** try to fake `ro.vndk.version` / target-level — without the newer VNDK libraries it only
   breaks HAL loading. A16/17 = kernel track.
