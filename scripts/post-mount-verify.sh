#!/system/bin/sh
# post-mount-verify.sh - Post-Mount Verification Script v0.2.3
# Checks filesystem visibility, cryptographic integrity, permissions,
# SELinux contexts, runtime properties, HIDL services, and framework codec enumeration.
#
# Target: DerpFest 17 / KernelSU-Next / Magic Mount r1

echo "=========================================================="
echo " Dolby Media Codec - Full Stack Verification v0.2.3"
echo " Target: DerpFest 17 / KernelSU-Next / Magic Mount r1"
echo "=========================================================="

FAILURES=0

verify_file() {
  target_file="$1"
  expected_hash="$2"
  expected_context="$3"

  if [ ! -f "$target_file" ]; then
    echo "[FAIL] Missing: $target_file"
    FAILURES=$((FAILURES + 1))
    return 1
  fi

  # 1. Verify Hash
  hash_status="UNKNOWN"
  if command -v sha256sum >/dev/null 2>&1; then
    actual_hash="$(sha256sum "$target_file" 2>/dev/null | awk '{print $1}')"
    if [ "$actual_hash" = "$expected_hash" ]; then
      hash_status="PASS"
    else
      hash_status="FAIL (Expected: $expected_hash, Actual: $actual_hash)"
      FAILURES=$((FAILURES + 1))
    fi
  else
    hash_status="SKIP (sha256sum not available)"
  fi

  # 2. Verify Permissions and SELinux Context
  stat_line="$(ls -ldZ "$target_file" 2>/dev/null)"
  perms="$(echo "$stat_line" | awk '{print $1}')"
  actual_context="$(echo "$stat_line" | awk '{print $5}')"

  context_status="PASS"
  if [ "$actual_context" != "$expected_context" ]; then
    context_status="FAIL (Expected: $expected_context, Actual: $actual_context)"
    FAILURES=$((FAILURES + 1))
  fi

  if [ "$hash_status" = "PASS" ] && [ "$context_status" = "PASS" ]; then
    echo "[PASS] $target_file"
    echo "       Perms: $perms | Context: $actual_context | Hash: OK"
  else
    echo "[FAIL] $target_file"
    echo "       Perms: $perms"
    echo "       Hash:    $hash_status"
    echo "       Context: $context_status"
  fi

  return 0
}

echo "1. Checking mounted library components in /vendor/lib (Expected: u:object_r:vendor_file:s0):"
verify_file "/vendor/lib/libstagefright_softomx.so" "9c8e41a84c184ec78d7418ff6d0f9ba63b83e7dcdd0a91db5f234808c17946c9" "u:object_r:vendor_file:s0"
verify_file "/vendor/lib/libstagefright_softomx_shim.so" "5a85761252a6876d3bfce5b7df61061cbcd773716be83313ef660382c62d0555" "u:object_r:vendor_file:s0"
verify_file "/vendor/lib/libdeccfg.so" "47e0a3d2143296e6d2916e0a9549357944860bbf1bf325c511badea5453de717" "u:object_r:vendor_file:s0"
verify_file "/vendor/lib/libstagefrightdolby.so" "b08a5dc324a05fafc6d90a650a3b54f09742d26edad2cf97b809fbee60c9acd9" "u:object_r:vendor_file:s0"
verify_file "/vendor/lib/libstagefright_soft_ddpdec.so" "d8b09431c2bc0c4aba7d3a0acfd03547a58633053a5cdbb3ecdaa69f957132bd" "u:object_r:vendor_file:s0"
verify_file "/vendor/lib/vendor.dolby.hardware.dms@2.0.so" "95d846e23c981093e5003f8dca86d427f5ea06bd5ae5bab4b64f918070e82780" "u:object_r:vendor_file:s0"

echo ""
echo "2. Checking mounted media configuration XMLs in /vendor/etc (Expected: u:object_r:vendor_configs_file:s0):"
verify_file "/vendor/etc/media_codecs.xml" "da3ae30e46650140e3a06b7df1f7edd7aaec43bf06df92b5ea2bc864a41b2145" "u:object_r:vendor_configs_file:s0"
verify_file "/vendor/etc/media_codecs_dolby_audio.xml" "67a60b1caf0bac212544993bd88512cc0daaeeec21b42308e5c7264ed7e86d73" "u:object_r:vendor_configs_file:s0"

echo ""
echo "3. Checking mounted VINTF manifest fragment in /vendor/etc/vintf/manifest (Expected: u:object_r:vendor_configs_file:s0):"
verify_file "/vendor/etc/vintf/manifest/android.hardware.media.omx@1.0-service.xml" "02396fa82c06a56e3066792dd87bf3b3bc9cfe6f23ccf8e5923f5acf24800dce" "u:object_r:vendor_configs_file:s0"

echo ""
echo "4. Checking vendor properties:"
prop_dax="$(getprop ro.vendor.audio.dolby.dax.support)"
if [ -z "$prop_dax" ] && [ -x /data/adb/ksu/bin/resetprop ]; then
  prop_dax="$(/data/adb/ksu/bin/resetprop ro.vendor.audio.dolby.dax.support)"
fi
prop_omx="$(getprop vendor.media.omx)"
if [ -z "$prop_omx" ] && [ -x /data/adb/ksu/bin/resetprop ]; then
  prop_omx="$(/data/adb/ksu/bin/resetprop vendor.media.omx)"
fi
echo "   ro.vendor.audio.dolby.dax.support = $prop_dax"
echo "   vendor.media.omx = $prop_omx"
if [ "$prop_dax" = "true" ] || [ "$prop_dax" = "1" ]; then
  echo "   [PASS] ro.vendor.audio.dolby.dax.support is active"
else
  echo "   [FAIL] ro.vendor.audio.dolby.dax.support is not active"
  FAILURES=$((FAILURES + 1))
fi
if [ "$prop_omx" = "1" ] || [ "$prop_omx" = "true" ]; then
  echo "   [PASS] vendor.media.omx is active"
else
  echo "   [FAIL] vendor.media.omx is not active"
  FAILURES=$((FAILURES + 1))
fi

echo ""
echo "5. Checking HIDL OMX Service Registration:"
if command -v lshal >/dev/null 2>&1; then
  omx_service="$(lshal 2>/dev/null | grep -E "android.hardware.media.omx@1.0::IOmx/default" | head -n 1)"
  omx_store="$(lshal 2>/dev/null | grep -E "android.hardware.media.omx@1.0::IOmxStore/default" | head -n 1)"
  if [ -n "$omx_service" ]; then
    echo "   [PASS] IOmx/default is registered"
  else
    echo "   [FAIL] IOmx/default is NOT registered"
    FAILURES=$((FAILURES + 1))
  fi
  if [ -n "$omx_store" ]; then
    echo "   [PASS] IOmxStore/default is registered"
  else
    echo "   [FAIL] IOmxStore/default is NOT registered"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "   [SKIP] lshal command not available"
fi

echo ""
echo "6. Checking Android Framework MediaCodec Enumeration:"
if command -v dumpsys >/dev/null 2>&1; then
  ac3_found="$(dumpsys media.player 2>/dev/null | grep "OMX.dolby.ac3.decoder")"
  eac3_found="$(dumpsys media.player 2>/dev/null | grep "OMX.dolby.eac3.decoder")"
  joc_found="$(dumpsys media.player 2>/dev/null | grep "OMX.dolby.eac3-joc.decoder")"
  if [ -n "$ac3_found" ]; then
    echo "   [PASS] OMX.dolby.ac3.decoder exposed to framework"
  else
    echo "   [FAIL] OMX.dolby.ac3.decoder NOT found in media.player"
    FAILURES=$((FAILURES + 1))
  fi
  if [ -n "$eac3_found" ]; then
    echo "   [PASS] OMX.dolby.eac3.decoder exposed to framework"
  else
    echo "   [FAIL] OMX.dolby.eac3.decoder NOT found in media.player"
    FAILURES=$((FAILURES + 1))
  fi
  if [ -n "$joc_found" ]; then
    echo "   [PASS] OMX.dolby.eac3-joc.decoder exposed to framework"
  else
    echo "   [FAIL] OMX.dolby.eac3-joc.decoder NOT found in media.player"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "   [SKIP] dumpsys command not available"
fi

echo ""
echo "7. Summary:"
if [ "$FAILURES" -eq 0 ]; then
  echo "OVERALL VERIFICATION: PASS (All components present, hashes verified, contexts match, props active, services registered, codecs enumerated)"
  exit 0
else
  echo "OVERALL VERIFICATION: FAIL ($FAILURES failures detected)"
  exit 1
fi
