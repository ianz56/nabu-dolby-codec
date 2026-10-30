# Changelog

All notable changes to the **nabu-dolby-codec** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.3] - 2026-10-31

### Added
- Early boot vendor property triggers in `system.prop` and `post-fs-data.sh`:
  - `ro.vendor.audio.dolby.dax.support=true`: gates `addVendorPlugin()` in `libstagefright_omx.so`.
  - `vendor.media.omx=1`: gates SPHAL dynamic library loading in `libstagefright_omx.so`.
- VINTF manifest fragment at `/vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml` satisfying Device Manifest (`DM`) and Framework Compatibility Matrix (`FC`).
- Multi-tier diagnostic script `post-mount-verify.sh` checking file presence, hashes, SELinux contexts, properties, HIDL registration, and framework enumeration.
- Automated packaging utility `scripts/build-module.sh` for reproducible local assembly from proprietary blobs.

### Changed
- Promoted module to production-ready status after verifying persistent cold-boot startup.
- Updated `module.prop` versionCode to `5` and version to `0.2.3`.

### Fixed
- Resolved silent bypass of `libstagefrightdolby.so` caused by missing vendor property flags.
- Resolved missing HIDL OMX service registration in `hwservicemanager`.
- Enabled full framework codec enumeration for:
  - `audio/ac3` (`OMX.dolby.ac3.decoder`)
  - `audio/eac3` (`OMX.dolby.eac3.decoder`)
  - `audio/eac3-joc` (`OMX.dolby.eac3-joc.decoder`)

---

## [0.2.2] - 2026-10-31

### Added
- Integrated candidate VINTF manifest fragment for testing `IOmx` and `IOmxStore` service exposure.

---

## [0.2.1] - 2026-10-31

### Fixed
- Resolved SELinux context mismatch on overlay mounts (`u:object_r:system_file:s0` $\rightarrow$ `vendor_file:s0` / `vendor_configs_file:s0`).
- Eliminated `mediacodec` AVC denials when reading `/vendor/etc/media_codecs.xml`.

---

## [0.2.0] - 2026-10-30

### Added
- Initial full Magisk/KernelSU package structure requiring Magic Mount r1 metamodule.
- Patched `libstagefright_softomx.so` with `DT_NEEDED` pointing to `libstagefright_softomx_shim.so`.
- Pure C freestanding GraphicBufferMapper compatibility shim resolving Android 17 symbol breakages.
- Complete vendor XML codec definitions.

---

## [0.1.0] - 2026-10-29

### Added
- Initial project audit and extraction of Xiaomi HyperOS vendor multimedia blobs for Xiaomi Pad 5 (`nabu`).
- Identification of 32-bit SoftOMX dynamic linking failures on 64-bit Android 17.
