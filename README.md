# Dolby Media Codec Integration for Xiaomi Pad 5 (`nabu`)

[![Android](https://img.shields.io/badge/Android-17%20%28API%2037%29-green.svg)](https://source.android.com/)
[![Kernel](https://img.shields.io/badge/Kernel-4.14.357-blue.svg)](https://kernel.org/)
[![Root](https://img.shields.io/badge/KernelSU--Next-v3.3.0-orange.svg)](https://github.com/KernelSU-Next/KernelSU-Next)
[![SELinux](https://img.shields.io/badge/SELinux-Enforcing-success.svg)](#selinux-security)
[![Release](https://img.shields.io/badge/Release-v0.2.3--final-brightgreen.svg)](#production-release-package)

Systemless Dolby AC3, E-AC3, and E-AC3 JOC codec integration for the **Xiaomi Pad 5 (`nabu` / `nabu_global`)** running **DerpFest 17 (Android 17 / API 37)**.

---

## 1. Project Overview

Modern AOSP custom ROMs for Xiaomi devices typically ship with pure 64-bit media pipelines and standard Codec2 software components. Legacy vendor-specific hardware-accelerated decoders from OEM firmware (such as Xiaomi HyperOS) are omitted.

This project integrates the vendor-optimized 32-bit Dolby OMX decoders systemlessly onto DerpFest 17 without modifying physical partitions, without disabling SELinux, and without destabilizing the platform media framework.

### Supported Decoders & Media Types

| MIME Type | Codec Component Name | Specifications | Hardware Accelerated |
| :--- | :--- | :--- | :---: |
| `audio/ac3` | `OMX.dolby.ac3.decoder` | Up to 6 channels, 32–48 kHz, 32–640 kbps | **Yes** |
| `audio/eac3` | `OMX.dolby.eac3.decoder` | Up to 8 channels, 32–48 kHz, 32–6144 kbps | **Yes** |
| `audio/eac3-joc` | `OMX.dolby.eac3-joc.decoder` | Up to 8 channels, 48 kHz, 32–6144 kbps (Joint Object Coding) | **Yes** |

---

## 2. Technical Architecture

The module addresses five technical challenges inherent to running legacy vendor blobs under Android 17:

1. **Freestanding C Compatibility Shim (`libstagefright_softomx_shim.so`):**  
   Android 17 removed legacy 7-parameter `GraphicBufferMapper::lock` and 2-parameter `unlock` symbols from `/vendor/lib/libui.so`. A pure C compatibility bridge maps these calls to modern equivalents without adding `libc` runtime dependencies.
2. **Patched SoftOMX Engine (`libstagefright_softomx.so`):**  
   The dynamic section (`DT_NEEDED`) of Xiaomi's legacy SoftOMX library is patched to route buffer mapping calls through the compatibility shim.
3. **Modular VINTF Fragment:**  
   Projects an explicit HAL declaration into `/vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml`, satisfying both Device Manifest (`DM`) and Framework Compatibility Matrix (`FC`).
4. **Early Boot Property Gates:**  
   DerpFest 17 lacks Xiaomi's OEM properties. The module initializes:
   - `ro.vendor.audio.dolby.dax.support=true`: activates Dolby plugin discovery in `libstagefright_omx.so`.
   - `vendor.media.omx=1`: activates SPHAL dynamic library loading in `libstagefright_omx.so`.
5. **Magic Mount r1 Metamodule Overlay:**  
   Projects the payload into `/vendor` at boot with strict `u:object_r:vendor_file:s0` and `u:object_r:vendor_configs_file:s0` SELinux contexts.

Detailed documentation is available in [docs/architecture.md](docs/architecture.md).

---

## 3. Important Limitations

> [!WARNING]
> **E-AC3 JOC Decoding vs. Spatial Audio Rendering**  
> Decoding `audio/eac3-joc` (Dolby Digital Plus with Joint Object Coding / Atmos bitstream) extracts multichannel object-based audio streams. However, **codec decoding alone does not configure or guarantee Dolby Atmos DAP (Digital Audio Processing) effect processing or spatial audio rendering through the speaker/headphone DSP pipeline**. Full Atmos virtualization requires additional audio HAL effect wrappers and OEM soundfx libraries.

---

## 4. Requirements & Prerequisites

- **Device:** Xiaomi Pad 5 (`nabu`)
- **ROM:** DerpFest 17 (Android 17 / API 37, Linux 4.14.357)
- **Root Framework:** KernelSU-Next v3.3.0 or higher
- **Mandatory Metamodule:** Magic Mount r1 (`magic_mount_rs-4.0.12-941-arm64-nabu-patched-final-candidate-r1.zip`)
- **SELinux Mode:** `Enforcing` (Supported and verified)

---

## 5. Production Release Package

The verified production module package is:
- **File:** `nabu-dolby-codec-v0.2.3-final.zip`
- **SHA-256:** `e6dab2e6396e6f5df3252691a91ca83d7d98fbd14f3bb67c69f54adc940658d1`
- **Size:** 1,315,294 bytes (approx 1.3 MB)

Refer to [manifests/artifact-hashes.txt](manifests/artifact-hashes.txt) for the full integrity ledger.

---

## 6. Building the Module from Source

Due to copyright restrictions, **this repository does NOT distribute proprietary Xiaomi or Dolby binary blobs**.

To build the module locally:

### Step 1: Supply Vendor Blobs
Create a `blobs/` directory in the repository root and place the following 5 vendor shared libraries extracted from stock Xiaomi Pad 5 firmware:
1. `libdeccfg.so` (SHA-256: `47e0a3d2143296e6d2916e0a9549357944860bbf1bf325c511badea5453de717`)
2. `libstagefrightdolby.so` (SHA-256: `b08a5dc324a05fafc6d90a650a3b54f09742d26edad2cf97b809fbee60c9acd9`)
3. `libstagefright_soft_ddpdec.so` (SHA-256: `d8b09431c2bc0c4aba7d3a0acfd03547a58633053a5cdbb3ecdaa69f957132bd`)
4. `libstagefright_softomx.so` (SHA-256: `9c8e41a84c184ec78d7418ff6d0f9ba63b83e7dcdd0a91db5f234808c17946c9`)
5. `vendor.dolby.hardware.dms@2.0.so` (SHA-256: `95d846e23c981093e5003f8dca86d427f5ea06bd5ae5bab4b64f918070e82780`)

### Step 2: Run Build Script
Execute the build script:
```bash
./scripts/build-module.sh
```
The script will:
- Automatically compile `source/libstagefright_softomx_shim.c` using Clang.
- Verify cryptographic hashes for all vendor blobs.
- Assemble directory structures and apply permissions.
- Produce `dist/nabu-dolby-codec-v0.2.3-final.zip`.

---

## 7. Runtime Validation Evidence

Post-mount verification on a fresh, cold-booted DerpFest 17 device demonstrates:
```text
==========================================================
 Dolby Media Codec - Full Stack Verification v0.2.3
 Target: DerpFest 17 / KernelSU-Next / Magic Mount r1
==========================================================
1. Checking mounted library components in /vendor/lib:
[PASS] /vendor/lib/libstagefright_softomx.so
[PASS] /vendor/lib/libstagefright_softomx_shim.so
[PASS] /vendor/lib/libdeccfg.so
[PASS] /vendor/lib/libstagefrightdolby.so
[PASS] /vendor/lib/libstagefright_soft_ddpdec.so
[PASS] /vendor/lib/vendor.dolby.hardware.dms@2.0.so

2. Checking mounted media configuration XMLs in /vendor/etc:
[PASS] /vendor/etc/media_codecs.xml
[PASS] /vendor/etc/media_codecs_dolby_audio.xml

3. Checking mounted VINTF manifest fragment in /vendor/etc/vintf/manifest:
[PASS] /vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml

4. Checking vendor properties:
   [PASS] ro.vendor.audio.dolby.dax.support is active
   [PASS] vendor.media.omx is active

5. Checking HIDL OMX Service Registration:
   [PASS] IOmx/default is registered
   [PASS] IOmxStore/default is registered

6. Checking Android Framework MediaCodec Enumeration:
   [PASS] OMX.dolby.ac3.decoder exposed to framework
   [PASS] OMX.dolby.eac3.decoder exposed to framework
   [PASS] OMX.dolby.eac3-joc.decoder exposed to framework

7. Summary:
OVERALL VERIFICATION: PASS
```

See [docs/runtime-validation.md](docs/runtime-validation.md) for full execution traces and testing methods.

---

## 8. License & Disclaimer

- The C source code (`source/libstagefright_softomx_shim.c`), configuration templates, and shell scripts authored for this project are provided under the Apache License 2.0.
- Dolby, Dolby Audio, Dolby Atmos, AC3, and E-AC3 are registered trademarks of Dolby Laboratories Licensing Corporation. This project is an independent interoperability bridge and is not affiliated with or endorsed by Dolby Laboratories or Xiaomi Inc.
