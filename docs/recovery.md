# Recovery & Module Rollback Guide

## 1. Safety Architecture

The `nabu-dolby-codec` module utilizes a **100% systemless** implementation via KernelSU-Next and Magic Mount r1:
- Physical `/system`, `/vendor`, and `/boot` partitions remain untouched and read-only.
- All files are projected from `/data/adb/modules/nabu-dolby-codec`.
- If a boot loop or instability occurs, removing or disabling the module instantly restores the device to its pristine stock ROM state.

---

## 2. Emergency Rollback Procedures

### Method 1: KernelSU Safe Mode (Physical Key Sequence)
KernelSU features a hardware-triggered safe mode that disables all modules during early boot:
1. Long-press the **Power** button until the device begins rebooting.
2. Immediately when the "MI" boot logo appears, press and hold the **Volume Down** key.
3. Keep holding until the device boots into Android Safe Mode (or KernelSU safe mode).
4. All modules will be disabled automatically.
5. Open KernelSU Manager or run ADB:
   ```bash
   adb shell "su -c 'touch /data/adb/modules/nabu-dolby-codec/disable'"
   ```
6. Reboot normally.

---

### Method 2: ADB Shell Module Disable (If Device Boots)
If the device boots but experiencing service crashes, disable the module via ADB:
```bash
# Create disable flag
adb shell "su -c 'touch /data/adb/modules/nabu-dolby-codec/disable'"

# Reboot device
adb reboot
```

To completely delete the module:
```bash
adb shell "su -c 'rm -rf /data/adb/modules/nabu-dolby-codec'"
adb reboot
```

---

### Method 3: Fastboot Recovery (Complete Fallback)
If the device fails to reach user-space and safe mode is inaccessible, boot into Fastboot mode:
1. Power off device completely.
2. Hold **Power + Volume Down** until Fastboot screen appears.
3. Verify connection:
   ```bash
   fastboot devices
   ```
4. Flash the pristine boot image from the official DerpFest ROM archive:
   ```bash
   fastboot flash boot boot.img
   ```
   *(This temporarily disables KernelSU execution, allowing normal boot without any modules).*
5. Boot device:
   ```bash
   fastboot reboot
   ```
6. After booting, re-patch and re-flash the KernelSU boot image.

---

## 3. Official ROM Verification

Reference DerpFest 17 distribution archive:
- **Archive:** `Auto-Installer_DerpFest-v17-20261023-11-56-nabu-Official-Stable_FASTBOOT_RECOVERY.zip`
- **Canonical SHA-256:** `96a32ae5bc0be1cb41724f8d298375e5338002dfbc34c3116fc5a5585ff6dcbe`
