# OneOS on the Galaxy A31 (SM-A315F)

Bring-up notes for adding the A31 to OneOS. Status: **in progress — not yet boot-confirmed.**
Nothing here is marked "working" until a guest reaches the home screen on a real A31 with
evidence (logcat / screenshot / `dumpsys`), per the project's honesty rule.

## Device
- Model **SM-A315F**, codename **a31**, SoC **MediaTek MT6768** (Helio P65), **arm64**, **4 GB RAM**, form **bar**.
- Stock: One UI, Android 12, ext4 vendor. Custom kernels in progress (4.14 "Atrocious" boots; 4.19 does not yet).
- GPU Mali-G52 MC2 (vendor userspace bifrost r25p0); TEE Trustonic 410.

## What is wired
- Device entry in `assets/root/oneos_root.sh`:
  `a31) echo "SM-A315F a31 MT6768 bar" ;;`  (profile key `a31` -> MODEL/codename/SoC/form).

## What still needs wiring (before the app offers A31)
1. A `Profiles.BUILT_IN` entry for `a31` in the Kotlin model (form = phone/bar, display density
   from the device probe — run `probe-a31.sh`, read `ro.sf.lcd_density` and `wm density`).
2. Pick the first guest image to try. MT6768 is older than the currently-tested SoCs, so start with
   the lightest AOSP-ish guest (not a heavy Pixel/ColorOS build) to isolate vendor-age problems.
3. Confirm root: OneOS needs KernelSU (tested) or Magisk; the A31 currently runs Magisk.

## Known risk (read first)
The A31's vendor/kernel are older than OneOS's One UI 8/9 assumptions. Upstream warns that too-old
vendor software may stop a guest from starting. The **Lumi vendor** work (patching the A31 vendor for
Android 16/17 GSI requirements: VINTF, bpfloader/eBPF, SELinux, props) is the enabler and is tracked
separately. Expect iteration; keep the stock boot as a fallback.
