# Architectural Architecture & Technical Design

## 1. System Overview

The **nabu-dolby-codec** module integrates Dolby AC3, E-AC3, and E-AC3 JOC hardware-accelerated software decoders into the Xiaomi Pad 5 (`nabu`) running **DerpFest 17 (Android 17 / API 37)**.

Because modern custom ROMs for `nabu` ship with pure 64-bit media pipelines and standard AOSP Codec2 components, legacy vendor OMX components from Xiaomi HyperOS (Android 13) cannot operate without resolving:
1. **Multilib ABI constraints:** Legacy Dolby decoders are compiled as 32-bit ARMv7-A (`armeabi-v7a`) binaries that execute inside the 32-bit `mediaswcodec` or `android.hardware.media.omx@1.0-service` process.
2. **GraphicBufferMapper ABI mismatch:** `libstagefright_softomx.so` depends on deprecated 7-parameter `lock` and 2-parameter `unlock` symbols removed in newer Android releases.
3. **HIDL Service VINTF compatibility:** Android 17 ignores undeclared legacy HALs unless an explicit manifest fragment is projected into `/vendor/etc/vintf/manifest/`.
4. **Vendor Property Gates:** Qualcomm/Xiaomi's `libstagefright_omx.so` contains strict runtime property checks that silently abort plugin loading if Dolby feature flags are absent.
5. **SELinux MLS Enforcement:** All projected binaries and configurations must possess exact `u:object_r:vendor_file:s0` and `u:object_r:vendor_configs_file:s0` contexts.

---

## 2. Stack Architecture

```
+---------------------------------------------------------------------------------+
|                       Client Applications (Audio / Video Playback)               |
|            ExoPlayer, VLC, Netflix, Apple Music, CodecInfo, MX Player           |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
|                      Android 17 Framework Media Subsystem                       |
|           /system/bin/mediaserver  &  /system/bin/mediacodeclist_generator       |
|                                                                                 |
|   MediaCodecListGenerator queries OmxInfoBuilder(false) -> IOmxStore::listRoles |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
|                       HIDL Media HAL (hwservicemanager)                         |
|   android.hardware.media.omx@1.0::IOmx/default                                  |
|   android.hardware.media.omx@1.0::IOmxStore/default                             |
|                                                                                 |
|   Validated via VINTF fragment:                                                 |
|   /vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml         |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
|                OMX Service Process (/vendor/bin/hw/...)                         |
|   PID 1647: media.codec / android.hardware.media.omx@1.0-service (ARM32)       |
|                                                                                 |
|   Gate 1: ro.vendor.audio.dolby.dax.support == true                             |
|   Gate 2: vendor.media.omx == 1                                                 |
|                                                                                 |
|   Loaded Plugins:                                                               |
|   ├── libstagefrightdolby.so                                                    |
|   ├── libstagefright_softomx.so (Patched DT_NEEDED)                             |
|   │     └── libstagefright_softomx_shim.so (GraphicBufferMapper C Shim)         |
|   │           └── /vendor/lib/libui.so                                          |
|   ├── libstagefright_soft_ddpdec.so (DDP_JOCDecoder implementation)             |
|   ├── libdeccfg.so                                                              |
|   └── vendor.dolby.hardware.dms@2.0.so                                          |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
|                        KernelSU-Next & Magic Mount r1                           |
|   Kernel-level overlay projecting payload into /vendor without physical writes  |
|   SELinux: Enforcing (u:object_r:vendor_file:s0, vendor_configs_file:s0)        |
+---------------------------------------------------------------------------------+
```

---

## 3. GraphicBufferMapper C Compatibility Shim

### 3.1 Symbol Mismatch Analysis

`libstagefright_softomx.so` imports legacy symbols from `libui.so`:
- `_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_` (7 arguments)
- `_ZN7android19GraphicBufferMapper6unlockEPK13native_handle` (2 arguments)

However, Android 17's `/vendor/lib/libui.so` only exports modern symbols:
- `_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv` (5 arguments / 4 params + this)
- `_ZN7android19GraphicBufferMapper6unlockEPK13native_handlePNS_4base14unique_fd_implINS4_13DefaultCloserEEE` (3 arguments / 2 params + fence + this)

### 3.2 Pure C Shim Implementation

`libstagefright_softomx_shim.c` is written in freestanding C without dependencies on `libc.so` or `libc++.so`.
- **Assembler Labels:** Mangled C++ symbols are bound directly to standard C function prototypes via `__asm__`:
  ```c
  __attribute__((visibility("default")))
  int32_t shim_legacy_lock(...) __asm__("_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_");
  ```
- **Fail-Closed Contract:** If the caller passes non-NULL stride pointers (`outBytesPerPixel` or `outBytesPerStride`), the shim returns `-ENOSYS` immediately without attempting a broken lock.
- **Fence Pass-Through:** Legacy unlock passes `NULL` fenceOut to modern unlock, allowing the mapper to manage synchronization internally.

---

## 4. Vendor Property Gatekeepers

Disassembly of Qualcomm/Xiaomi's `/vendor/lib/libstagefright_omx.so` uncovered two crucial gating functions in `android::OMXStore`:

### 4.1 Dolby DAX Support Gate
```thumb
158d4: ldr  r0, =ro.vendor.audio.dolby.dax.support
158da: blx  property_get_bool (default 0)
158de: cmp  r0, #0
158e0: it   eq
158e2: popeq {r4, r5, r7, pc}   <-- RETURNS IMMEDIATELY IF FALSE
158fc: ldr  r1, =libstagefrightdolby.so
15906: b.w  addPlugin
```
Without `ro.vendor.audio.dolby.dax.support=true`, `addVendorPlugin()` never attempts to register `libstagefrightdolby.so`.

### 4.2 SPHAL Dynamic Loading Gate
```thumb
159a2: blx  GetIntProperty("vendor.media.omx", 0)
159c6: orrs.w r0, r6, r7
159ca: beq  0x15a56             <-- SKIPS SPHAL LOADING IF 0
```
Without `vendor.media.omx=1`, `android_load_sphal_library("libstagefrightdolby.so")` is bypassed.

Both properties are initialized in early boot via `system.prop` and `post-fs-data.sh`.
