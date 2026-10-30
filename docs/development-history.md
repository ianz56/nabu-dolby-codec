# Development History & Milestone Summary

## 1. Overview

The Dolby Media Codec integration for the Xiaomi Pad 5 (`nabu`) on DerpFest 17 (Android 17 / API 37) was engineered through an iterative, verification-driven methodology across multiple phases.

---

## 2. Phase-by-Phase Chronology

### Phase 4A: Static Binary Audit & Dependency Analysis
- **Scope:** Host-side static analysis of extracted Xiaomi HyperOS (Android 13) vendor blobs.
- **Key Discovery:** Identified that `libstagefright_softomx.so` failed dynamic linking on Android 17 due to missing legacy symbols `GraphicBufferMapper::lock` (7-parameter) and `unlock` (2-parameter) in `/vendor/lib/libui.so`.
- **Milestone:** Patched `libstagefright_softomx.so` ELF dynamic section (`DT_NEEDED`) to insert dependency on `libstagefright_softomx_shim.so`.

### Phase 4B.1: Pure-C Compatibility Shim
- **Scope:** Design, compilation, and static verification of the compatibility bridge.
- **Architecture:** Authored `libstagefright_softomx_shim.c` in freestanding C with explicit GCC/Clang `__asm__` symbol aliasing to C++ mangled names.
- **Milestone:** Produced bit-for-bit reproducible ARM32 (`armeabi-v7a`) binary matching golden SHA-256 `5a85761252a6876d3bfce5b7df61061cbcd773716be83313ef660382c62d0555` with zero external C-runtime dependencies.

### Phase 4B.2: Module Packaging & Validation
- **Scope:** First complete packaging of the 8-component payload into Magisk/KernelSU ZIP structure.
- **Milestone:** Generated `nabu-dolby-codec-v0.2.0-final.zip` (SHA-256: `0a064e701a72accecc8e25f145e80a9657d0605e776e8ef53c5ec0a67647958b`).

### Phase 4C: Recovery & Rollback Audit
- **Scope:** Comprehensive audit of ROM packages, partition tables, and rollback safety.
- **Milestone:** Verified DerpFest 17 Fastboot/Recovery archive integrity (`Auto-Installer_DerpFest-v17-20261023-11-56-nabu-Official-Stable_FASTBOOT_RECOVERY.zip`) and established fail-safe rollback procedures.

### Phase 4D.1: Live Device Preflight
- **Scope:** First live ADB read-only audit of freshly installed DerpFest 17 on Xiaomi Pad 5.
- **Milestone:** Validated target environment: Linux kernel 4.14.357, KernelSU-Next v3.3.0, clean vendor partition, and Enforcing SELinux.

### Phase 4D.2: Metamodule Installation & Activation
- **Scope:** Installation and validation of Magic Mount r1 (`magic_mount_rs-4.0.12-941-arm64-nabu-patched-final-candidate-r1.zip`).
- **Milestone:** Confirmed Magic Mount projected `/system/vendor` partitions successfully under Android 17.

### Phase 4D.3: Initial Dolby Module Deployment & SELinux Diagnosis
- **Scope:** Installed `v0.2.0-final` on live device.
- **Observation:** All files mounted, but `mediacodec` failed with AVC denials when reading `/vendor/etc/media_codecs.xml`.
- **Root Cause:** Mount projected files with default `u:object_r:system_file:s0` instead of `vendor_file:s0` / `vendor_configs_file:s0`.

### Phase 4D.4: SELinux Context Remediation
- **Scope:** Updated installer script with explicit `set_perm_recursive` and `chcon -R` rules applying `u:object_r:vendor_file:s0` and `u:object_r:vendor_configs_file:s0`.
- **Milestone:** Released `v0.2.1-selinux`. AVC denials completely eliminated with SELinux strictly Enforcing.

### Phase 4D.5: VINTF Registration Diagnosis
- **Scope:** Diagnosed missing HIDL service registration for `IOmx/default` and `IOmxStore/default`.
- **Root Cause:** AOSP DerpFest 17 vendor manifest omitted `android.hardware.media.omx@1.0`.
- **Milestone:** Designed and validated minimal VINTF manifest fragment `android.hardware.media.omx@1.0-service.xml`.

### Phase 4D.6: Full-Stack Integration & Runtime Enumeration
- **Scope:** Package update to `v0.2.3-final`, incorporating VINTF manifest and vendor property triggers.
- **Breakthrough:** Disassembled `/vendor/lib/libstagefright_omx.so` and discovered two runtime property gates (`ro.vendor.audio.dolby.dax.support=true` and `vendor.media.omx=1`). Setting these enabled `mediacodec` to load `libstagefrightdolby.so`.
- **Outcome:** Full framework enumeration (`dumpsys media.player` exposed AC3, EAC3, EAC3-JOC), live component instantiation (`makeComponentInstance`), CodecInfo app GUI detection, and persistent 7/7 verification pass post-cold-boot.
