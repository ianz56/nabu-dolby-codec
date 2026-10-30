#!/system/bin/sh
# post-fs-data.sh - Early Boot Property Initialization
# Ensures vendor OMX and Dolby DAX triggers are active before media.codec starts.

if command -v resetprop >/dev/null 2>&1; then
  resetprop -n ro.vendor.audio.dolby.dax.support true
  resetprop -n vendor.media.omx 1
elif [ -x /data/adb/ksu/bin/resetprop ]; then
  /data/adb/ksu/bin/resetprop -n ro.vendor.audio.dolby.dax.support true
  /data/adb/ksu/bin/resetprop -n vendor.media.omx 1
fi
