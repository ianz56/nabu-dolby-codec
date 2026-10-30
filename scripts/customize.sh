#!/system/bin/sh
# Dolby Media Codec for Xiaomi Pad 5 (nabu) - Module Installer v0.2.3
# Target ROM: DerpFest 17 (Android 17 / API 37)
# Root Framework: KernelSU-Next v3.3.0
# Requires Metamodule: Magic Mount r1

ui_print "**********************************************"
ui_print "*   Dolby Media Codec - Xiaomi Pad 5 (nabu)  *"
ui_print "*   Target: DerpFest 17 (Android 17 / API37) *"
ui_print "*   v0.2.3 - VINTF Fragment & Vendor Props   *"
ui_print "**********************************************"

# Verify execution environment
if [ -z "$MODPATH" ]; then
  ui_print "! Error: MODPATH variable not set by installer."
  abort "Aborting installation."
fi

ui_print "- Configuring module permissions and SELinux contexts..."

# Set permissions for module metadata and verification script
set_perm "$MODPATH/module.prop" 0 0 0644
if [ -f "$MODPATH/system.prop" ]; then
  set_perm "$MODPATH/system.prop" 0 0 0644
fi
if [ -f "$MODPATH/post-fs-data.sh" ]; then
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
fi
if [ -f "$MODPATH/post-mount-verify.sh" ]; then
  set_perm "$MODPATH/post-mount-verify.sh" 0 0 0755
fi

# Set permissions and correct vendor SELinux contexts
# Format: set_perm_recursive <directory> <uid> <gid> <dmode> <fmode> [context]
set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
set_perm_recursive "$MODPATH/system/vendor" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm_recursive "$MODPATH/system/vendor/lib" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm_recursive "$MODPATH/system/vendor/etc" 0 0 0755 0644 u:object_r:vendor_configs_file:s0

# Explicit fallback ensuring security.selinux attributes on backing files
chcon -R u:object_r:vendor_file:s0 "$MODPATH/system/vendor/lib" 2>/dev/null || true
chcon -R u:object_r:vendor_configs_file:s0 "$MODPATH/system/vendor/etc" 2>/dev/null || true

ui_print "- VINTF Fragment integrated:"
ui_print "  * android.hardware.media.omx@1.0-service.xml"
ui_print "- Vendor Properties integrated:"
ui_print "  * ro.vendor.audio.dolby.dax.support=true"
ui_print "  * vendor.media.omx=1"
ui_print "- Codecs integrated:"
ui_print "  * audio/ac3      (OMX.dolby.ac3.decoder)"
ui_print "  * audio/eac3     (OMX.dolby.eac3.decoder)"
ui_print "  * audio/eac3-joc (OMX.dolby.eac3-joc.decoder)"
ui_print "- NOTICE: Requires Magic Mount Metamodule (r1) active."
ui_print "- Installation complete."
