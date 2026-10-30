# Installation Guide

## 1. Prerequisites

Before installing the `nabu-dolby-codec` module, ensure the target environment matches:

- **Target Device:** Xiaomi Pad 5 (`nabu` / `nabu_global`)
- **ROM:** DerpFest 17 (Android 17 / API 37)
- **Kernel:** Linux 4.14.357 (ARM64)
- **Root Framework:** KernelSU-Next v3.3.0 or higher
- **Mandatory Metamodule:** Magic Mount r1 (`magic_mount_rs-4.0.12-941-arm64-nabu-patched-final-candidate-r1.zip`)
  - *Magic Mount is strictly required* to project `/system/vendor` filesystem modifications under Android 17 without physical partition tampering.

---

## 2. Installation Procedure

### Step 1: Verify Metamodule Status
Confirm that Magic Mount r1 is installed and active in KernelSU-Next:
```bash
ksud module list
```
Ensure `magic_mount_rs` is listed and enabled.

### Step 2: Transfer Package to Device
Push the production module package to `/data/local/tmp`:
```bash
adb push nabu-dolby-codec-v0.2.3-final.zip /data/local/tmp/
```

Verify package integrity on the device:
```bash
adb shell "su -c 'sha256sum /data/local/tmp/nabu-dolby-codec-v0.2.3-final.zip'"
```
Expected hash:
`e6dab2e6396e6f5df3252691a91ca83d7d98fbd14f3bb67c69f54adc940658d1`

### Step 3: Install via KernelSU CLI or Manager
**Option A: Command-line installation (Recommended)**
```bash
adb shell "su -c 'ksud module install /data/local/tmp/nabu-dolby-codec-v0.2.3-final.zip'"
adb shell "su -c 'rm -f /data/local/tmp/nabu-dolby-codec-v0.2.3-final.zip'"
```

**Option B: KernelSU Manager GUI**
1. Open the KernelSU Manager application.
2. Navigate to the **Modules** tab.
3. Tap **Install from storage** and select `nabu-dolby-codec-v0.2.3-final.zip`.
4. Wait for the installation script to complete successfully.

### Step 4: Reboot Device
Perform a full system reboot to trigger Magic Mount projection, early-boot property registration, and media service startup:
```bash
adb reboot
```

---

## 3. Post-Mount Verification

After the tablet finishes booting (`sys.boot_completed=1`), run the built-in diagnostic script:
```bash
adb shell "su -c 'sh /data/adb/modules/nabu-dolby-codec/post-mount-verify.sh'"
```

A successful installation will output:
```text
OVERALL VERIFICATION: PASS (All components present, hashes verified, contexts match, props active, services registered, codecs enumerated)
```

---

## 4. Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `post-mount-verify.sh` reports missing files in `/vendor/lib` | Magic Mount metamodule is not installed or inactive | Install `magic_mount_rs-4.0.12-941-arm64-nabu-patched-final-candidate-r1.zip` first and reboot |
| `dumpsys media.player` does not list `OMX.dolby.*` | Vendor properties not set before `media.codec` startup | Verify `getprop ro.vendor.audio.dolby.dax.support` returns `true` and `getprop vendor.media.omx` returns `1`. If empty, inspect `/data/adb/modules/nabu-dolby-codec/post-fs-data.sh` |
| App crashes on playback | Missing `libstagefright_softomx_shim.so` or bad hash | Re-check binary SHA-256 against `manifests/artifact-hashes.txt` |
| SELinux denials in logcat (`avc: denied`) | Overlay directory contexts corrupted | Re-run `restorecon -Rv /data/adb/modules/nabu-dolby-codec` or reinstall package |
