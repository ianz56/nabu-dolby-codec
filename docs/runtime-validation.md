# Runtime Validation & Verification Runbook

## 1. Overview

This runbook outlines the multi-tiered verification procedure used to validate that the Dolby Media Codec subsystem is fully registered, memory-mapped, and operable within the Android 17 media framework.

---

## 2. Multi-Tier Verification Steps

### Tier 1: Post-Mount Verification Script
The primary automated diagnostic tool is `post-mount-verify.sh`:
```bash
adb shell "su -c 'sh /data/adb/modules/nabu-dolby-codec/post-mount-verify.sh'"
```
The script validates:
1. Presence, permissions (`0644`), SELinux contexts (`vendor_file:s0`), and SHA-256 hashes of all 6 `/vendor/lib/` binaries.
2. Presence, permissions, contexts (`vendor_configs_file:s0`), and hashes of both `/vendor/etc/` codec XML files.
3. Presence, permissions, context (`vendor_configs_file:s0`), and hash of `/vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml`.
4. State of `ro.vendor.audio.dolby.dax.support` and `vendor.media.omx`.
5. Registration of `IOmx/default` and `IOmxStore/default` in `hwservicemanager`.
6. Enumeration of `OMX.dolby.ac3.decoder`, `OMX.dolby.eac3.decoder`, and `OMX.dolby.eac3-joc.decoder` in `dumpsys media.player`.

---

### Tier 2: HIDL Service Discovery (`lshal`)
Verify that the HIDL OMX services are exposed and satisfy VINTF matrix constraints:
```bash
adb shell "lshal | grep -E 'omx'"
```
Expected output:
```text
DM,FC Y android.hardware.media.omx@1.0::IOmx/default       N/A   <mediacodec-pid>
DM,FC Y android.hardware.media.omx@1.0::IOmxStore/default  N/A   <mediacodec-pid>
```
- `DM` confirms declaration in Device Manifest.
- `FC` confirms satisfaction of Framework Compatibility Matrix.

---

### Tier 3: Framework Codec Enumeration (`dumpsys media.player`)
Inspect the framework decoder capabilities:
```bash
adb shell "dumpsys media.player"
```
Verify that the three Dolby decoders are reported:
```text
Media type 'audio/ac3':
  Decoder "OMX.dolby.ac3.decoder" supports
    attributes: 0xa: [ encoder: 0, vendor: 1, software-only: 0, hw-accelerated: 1 ]
    details: bitrate-range = "32000-640000", max-channel-count = "6", sample-rate-ranges = "32000,44100,48000"

Media type 'audio/eac3':
  Decoder "OMX.dolby.eac3.decoder" supports
    attributes: 0xa: [ encoder: 0, vendor: 1, software-only: 0, hw-accelerated: 1 ]
    details: bitrate-range = "32000-6144000", max-channel-count = "8", sample-rate-ranges = "32000,44100,48000"

Media type 'audio/eac3-joc':
  Decoder "OMX.dolby.eac3-joc.decoder" supports
    attributes: 0xa: [ encoder: 0, vendor: 1, software-only: 0, hw-accelerated: 1 ]
    details: bitrate-range = "32000-6144000", max-channel-count = "8", sample-rate-ranges = "48000"
```

---

### Tier 4: Memory Mapping Inspection
Locate the `mediacodec` OMX service process:
```bash
MEDIACODEC_PID=$(adb shell "pgrep -f 'android.hardware.media.omx@1.0-service'")
echo "MediaCodec PID: ${MEDIACODEC_PID}"
adb shell "su -c 'grep -E \"dolby|softomx|deccfg\" /proc/${MEDIACODEC_PID}/maps'"
```
Verify that all vendor shared libraries are loaded into memory:
- `/vendor/lib/libdeccfg.so`
- `/vendor/lib/vendor.dolby.hardware.dms@2.0.so`
- `/vendor/lib/libstagefright_softomx_shim.so`
- `/vendor/lib/libstagefright_softomx.so`
- `/vendor/lib/libstagefrightdolby.so`

---

### Tier 5: Runtime Component Instantiation Logcat
Monitor logcat while instantiating a Dolby component:
```bash
adb logcat -d -s OMXStore OmxStore DDP_JOCDecoder
```
Expected traces:
```text
I OMXStore: makeComponentInstance(OMX.dolby.eac3-joc.decoder) in android.hardware.media.omx@1.0-service process
I DDP_JOCDecoder: -> init name OMX.dolby.eac3-joc.decoder
```

---

### Tier 6: Graphical User Interface Test (`CodecInfo`)
Launch the CodecInfo application:
```bash
adb shell "am start -n com.parseus.codecinfo/.ui.MainActivity"
```
Verify via UI dump:
```bash
adb shell "uiautomator dump /data/local/tmp/window_dump.xml && cat /data/local/tmp/window_dump.xml | grep -o 'OMX.dolby.[^\"]*'"
adb shell "rm -f /data/local/tmp/window_dump.xml"
```
Confirm `OMX.dolby.ac3.decoder`, `OMX.dolby.eac3.decoder`, and `OMX.dolby.eac3-joc.decoder` appear in the list with hardware acceleration badges.
