# VINTF Manifest Integration & HAL Registration

## 1. VINTF Architecture in Android 17

Android's Vendor Interface (VINTF) object model enforces strict API contract compatibility between the system partition and vendor partition:
- **Device Manifest (DM):** Declares all HAL services and interfaces provided by the vendor implementation.
- **Framework Compatibility Matrix (FCM):** Declares all HAL requirements and optional interfaces supported by the system framework.

In modern Android versions (Android 14+ through Android 17), legacy HIDL OMX services (`android.hardware.media.omx@1.0`) are deprecated in favor of Codec2 (AIDL). Consequently, AOSP-based custom ROMs such as DerpFest 17 omit OMX declarations from their default vendor manifest.

---

## 2. The Registration Barrier

When `android.hardware.media.omx@1.0-service` boots and calls `registerAsService()` with `hwservicemanager`:
1. `hwservicemanager` checks the device's compiled VINTF manifest.
2. If `android.hardware.media.omx@1.0` is missing from the Device Manifest, `hwservicemanager` drops or isolates the service.
3. When framework clients (like `OmxInfoBuilder` or `MediaPlayerService`) query `getService()`, `hwservicemanager` returns `null`.
4. As a result, `lshal` reports the service as unregistered or missing from `DM`.

---

## 3. Systemless Manifest Fragment Solution

Android VINTF supports modular manifest fragments placed in `/vendor/etc/vintf/manifest/`.

The module projects a systemless fragment:
- **Target Path:** `/vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml`
- **Permissions:** `0644`
- **SELinux Context:** `u:object_r:vendor_configs_file:s0`

### Fragment Content
```xml
<manifest version="1.0" type="device">
    <hal format="hidl">
        <name>android.hardware.media.omx</name>
        <transport>hwbinder</transport>
        <version>1.0</version>
        <interface>
            <name>IOmx</name>
            <instance>default</instance>
        </interface>
        <interface>
            <name>IOmxStore</name>
            <instance>default</instance>
        </interface>
    </hal>
</manifest>
```

---

## 4. Verification

Upon reboot, `vintf` aggregates the fragment into the runtime device manifest.

Executing `lshal | grep omx` demonstrates complete registration:
```text
DM,FC Y android.hardware.media.omx@1.0::IOmx/default       N/A   1647
DM,FC Y android.hardware.media.omx@1.0::IOmxStore/default  N/A   1647
```
- **DM (Device Manifest):** Validated and present.
- **FC (Framework Compatibility Matrix):** Fully satisfied.
- **PID:** Active under `mediacodec` (PID 1647).
