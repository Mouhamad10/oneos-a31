# OneOS → Galaxy A31 (SM-A315F / MT6768) — Port Roadmap

Honest, code-grounded plan for bringing OneOS to the A31. Written so any maintainer or AI
assistant can continue without prior context. **Status: pillar 1 wired; not boot-confirmed.**

---

## 0. What OneOS actually is (read first)

OneOS is **not** "load a GSI as a guest." From `app-android/.../assets/root/oneos_root.sh`:
OneOS **stages a guest system** (one of the project's images) under `$STAGE`, installs a set of
**patched guest components** next to it — `vold_patched`, `surfaceflinger_patched`,
`services_patched.jar`, `telephony-common_patched.jar`, `*_payload.img`, etc. (the `SET_*` lists),
built from the image by `scripts/make-overlays.sh` — then **launches that guest as a container with
its own zygote and system_server on the HOST's kernel**, bridging it to the host's hardware/vendor.
`recover` restores the host's persist props after a session.

So a working phone needs **three things that match each other**: a *profile*, a *guest file set
built for that phone's kernel + vendor*, and a host the app's gate accepts.

---

## 1. The corrected diagnosis (important)

An earlier assumption — "the A31's Android-12 Lumi vendor is too old for OneOS guests" — is **wrong**.

Evidence from `Profiles.kt`, the **Galaxy A07** profile (the closest analog):
> `SM-A075, a07, MediaTek MT6789, vendor API **31 (Android 12)**, kernel 6.12` — and
> **Infinity-X (an Android-17 guest) reached the home screen on it** (0.4.60).

The A07 has the **same vendor API level (31 / Android 12)** as the A31's Lumi vendor, yet runs a
modern guest. OneOS bridges the vendor gap by patching the guest components. **The vendor age is not
the blocker.**

The real differences between the A07 (works) and the A31 (unconfirmed):

| | A07 (works) | A31 (target) |
|---|---|---|
| SoC | MT6789 | MT6768 (both MediaTek arm64) |
| Vendor API | 31 (A12) | **31 (A12)** — same ✅ |
| **Kernel** | **6.12** | **4.14** ← the likely hard blocker |
| **Host OS** | One UI 9 (A17) | an **Android-16 GSI** (already modern) — but **not One UI** |
| Guest file set | built for A07 | **none built for A31 yet** |

---

## 2. The four pillars (status + next step)

### Pillar 1 — Profile  ✅ DONE
`Profiles.kt` now has `A31` (`SM-A315`, `a31`, `MT6768`, BAR), registered in `BUILT_IN`, pointing at
the two lightest/AOSP-ish guests (`INFINITYX_CHOICE`, `LINEAGE_CHOICE`). It is flagged MEDIATEK +
`olderVendor("31 (Android 12)", "4.14")`. This only makes the app *recognize* the A31.

### Pillar 2 — A guest file set built for the A31  ⬜ THE BIG WORK
There is no `SET_*` for the A31. The patched guest components (`vold`, `surfaceflinger`,
`services.jar`, telephony, payloads) must be rebuilt so they run on the A31's **4.14 kernel + Lumi
vendor HALs**. This is the `scripts/make-overlays.sh` / MysticGSI pipeline applied to the A31:
1. Pick the lightest guest base (Infinity-X / LineageOS 24 — needs neither SVE nor SME, per A07).
2. Run the overlay pipeline against the A31 kernel headers + Lumi vendor to produce the patched set.
3. Package it as an `ImageChoice` + `PackageSet` the app can stage.
> This is the bulk of the effort and the main source of iteration.

### Pillar 3 — Host gate  ⬜
The app's compatibility checks expect **One UI** (`ro.build.version.oneui` in `ONE_UI_SEEN`/`_A16`).
The A31 runs a **generic Android-16 GSI**, which has no One UI version, so the gate/probe will refuse
it. Needs: relax the gate for the A31 profile (accept a GSI host), or run under the One UI the A31
can run (A12 — but then the host is old; the GSI host is actually preferable here).

### Pillar 4 — Kernel 4.14  ⬜ (verify early)
Every OneOS phone runs 5.x/6.x. The container mechanism (private zygote/system_server, mount/pid/net
namespaces, overlayfs, the launch bridges) may use kernel features the A31's 4.14 lacks. **This is
the first thing to test empirically** — it may be the ceiling. If 4.14 is insufficient, the A31 needs
a newer kernel (the 4.19 attempt, or a GKI 5.10 port) — tracked with the kernel work.

---

## 3. The empirical first loop (how to make real progress)

Mirror the NetHunter approach — *try, read the log, fix*:

1. **Build the APK** (the A-series goes in the `s25` variant): a GitHub Actions workflow with the
   Android SDK + Gradle building `app-android`. Confirm it compiles with the new A31 profile.
2. **Install** on the A31 (currently an Android-16 GSI + custom 4.14 kernel, Magisk root).
3. **Attempt a launch** with the lightest guest. It will most likely fail — **that is the point**.
4. **Read the session log** (`ONEOS_FULL_LOGS` capture). The first failure tells you which pillar
   breaks first: gate refusal (pillar 3), a missing kernel feature (pillar 4), or a guest/vendor HAL
   mismatch (pillar 2). Fix that, repeat.

Each loop converts "unknown" into a concrete, named blocker.

---

## 4. Honest expectations

This is a genuine multi-session port with real risk of not reaching "100%". The 4.14 kernel (pillar
4) and the from-scratch guest set (pillar 2) are the hard, uncertain parts. A realistic **first
milestone is a guest that attempts to start and produces a diagnosable log**, not a finished system.
Keep the stock boot as a fallback; never switch with a screen lock set.

## 5. Assets already in hand (reuse these)
- **Lumi vendor** (`vendor/` + the `vendor-lumi-ext4-v1` release): proven GSI-capable to ~A13; the
  patcher is `vendor/patch-vendor.sh`; analysis in `vendor/VENDOR-ANALYSIS.md`.
- **A31 NetHunter kernel** (`Mouhamad10/a31-nethunter`): a working 4.14 build + CI; the place to add
  any container-feature kernel configs pillar 4 turns out to need.
- Device facts in `docs/DEVICE-A31.md`.
