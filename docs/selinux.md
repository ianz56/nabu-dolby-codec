# SELinux Policy & Security Context Architecture

## 1. Security Architecture & Threat Model

On DerpFest 17 (Android 17 / API 37), SELinux operates in strict **Enforcing** mode. The platform relies on Multi-Level Security (MLS) and domain separation to sandbox media codecs:
- Native media decoders run within restricted security domains (`mediacodec`, `mediaswcodec`, `mediaserver`).
- The `mediacodec` domain possesses fine-grained allow rules for `/vendor` resources but is strictly prohibited from accessing unauthorized system or data domains.

---

## 2. The Context Mismatch Problem

When Magisk or KernelSU creates an overlay directory under `/data/adb/modules/<id>/system/...`, the backing ext4 inode on `/data` typically inherits `u:object_r:system_file:s0` or `u:object_r:magisk_file:s0`.

When Magic Mount r1 projects this structure onto `/vendor`:
- Files in `/vendor/lib` inherited `u:object_r:system_file:s0`.
- Files in `/vendor/etc` inherited `u:object_r:system_file:s0`.

As observed in Phase 4D.3, this resulted in immediate AVC denials when `mediacodec` tried to parse `/vendor/etc/media_codecs.xml`:
```text
avc: denied { read } for comm="media.codec" name="media_codecs.xml" dev="tmpfs" ino=... scontext=u:r:mediacodec:s0 tcontext=u:object_r:system_file:s0 tclass=file permissive=0
```
Because `mediacodec` cannot read `system_file`, codec registration silently aborted.

---

## 3. DerpFest 17 Context Specifications

Inspecting the target ROM's `/vendor/etc/selinux/vendor_file_contexts` revealed the required labels:

| Filesystem Path Pattern | Required SELinux Context | Description |
| :--- | :--- | :--- |
| `/vendor/lib(/.*)?` | `u:object_r:vendor_file:s0` | Vendor native shared libraries |
| `/vendor/etc(/.*)?` | `u:object_r:vendor_configs_file:s0` | Vendor XML configuration files |
| `/vendor/etc/vintf/manifest(/.*)?` | `u:object_r:vendor_configs_file:s0` | VINTF device manifest fragments |

---

## 4. Remediation Implementation

The module strictly avoids setting SELinux to `Permissive` and avoids injecting unsafe sepolicy rules. Instead, it enforces the exact vendor labels directly on the overlay backing files during installation in `customize.sh`:

```sh
# Set directory and file permissions with vendor contexts
set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
set_perm_recursive "$MODPATH/system/vendor" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm_recursive "$MODPATH/system/vendor/lib" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm_recursive "$MODPATH/system/vendor/etc" 0 0 0755 0644 u:object_r:vendor_configs_file:s0

# Explicit extended attribute fallback on underlying filesystem
chcon -R u:object_r:vendor_file:s0 "$MODPATH/system/vendor/lib" 2>/dev/null || true
chcon -R u:object_r:vendor_configs_file:s0 "$MODPATH/system/vendor/etc" 2>/dev/null || true
```

When Magic Mount r1 constructs the mount projections, the projected virtual filesystem preserves the `security.selinux` xattrs. As a result, `mediacodec` accesses the files without triggering a single AVC denial.
