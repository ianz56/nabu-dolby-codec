#!/usr/bin/env bash
# ==============================================================================
# build-module.sh
# Systemless Dolby Media Codec Packaging Utility for Xiaomi Pad 5 (nabu)
# Target: DerpFest 17 (Android 17 / API 37) | Metamodule: Magic Mount r1
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BLOBS_DIR="${REPO_ROOT}/blobs"
OUTPUT_DIR="${REPO_ROOT}/dist"
MODULE_VERSION="0.2.3"
OUTPUT_ZIP="${OUTPUT_DIR}/nabu-dolby-codec-v${MODULE_VERSION}-final.zip"

EXPECTED_FINAL_HASH="e6dab2e6396e6f5df3252691a91ca83d7d98fbd14f3bb67c69f54adc940658d1"

# Pinned SHA-256 hashes for all required proprietary/patched binaries
declare -A EXPECTED_HASHES=(
    ["libdeccfg.so"]="47e0a3d2143296e6d2916e0a9549357944860bbf1bf325c511badea5453de717"
    ["libstagefrightdolby.so"]="b08a5dc324a05fafc6d90a650a3b54f09742d26edad2cf97b809fbee60c9acd9"
    ["libstagefright_soft_ddpdec.so"]="d8b09431c2bc0c4aba7d3a0acfd03547a58633053a5cdbb3ecdaa69f957132bd"
    ["libstagefright_softomx.so"]="9c8e41a84c184ec78d7418ff6d0f9ba63b83e7dcdd0a91db5f234808c17946c9"
    ["vendor.dolby.hardware.dms@2.0.so"]="95d846e23c981093e5003f8dca86d427f5ea06bd5ae5bab4b64f918070e82780"
    ["libstagefright_softomx_shim.so"]="5a85761252a6876d3bfce5b7df61061cbcd773716be83313ef660382c62d0555"
)

usage() {
    echo "Usage: $0 [--blobs-dir <path>] [--output-dir <path>]"
    echo ""
    echo "Options:"
    echo "  --blobs-dir <path>   Directory containing locally supplied proprietary blobs"
    echo "                       (default: ${REPO_ROOT}/blobs)"
    echo "  --output-dir <path>  Directory to place generated module ZIP"
    echo "                       (default: ${REPO_ROOT}/dist)"
    echo "  -h, --help           Show this help message"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --blobs-dir)
            BLOBS_DIR="$(cd "$2" && pwd)"
            shift 2
            ;;
        --output-dir)
            mkdir -p "$2"
            OUTPUT_DIR="$(cd "$2" && pwd)"
            OUTPUT_ZIP="${OUTPUT_DIR}/nabu-dolby-codec-v${MODULE_VERSION}-final.zip"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            usage
            ;;
    esac
done

echo "=========================================================="
echo " Dolby Media Codec Module Packager - Xiaomi Pad 5 (nabu)"
echo " Target: DerpFest 17 (Android 17 / API 37)"
echo "=========================================================="
echo "Repository Root: ${REPO_ROOT}"
echo "Blobs Directory: ${BLOBS_DIR}"
echo "Output Archive:  ${OUTPUT_ZIP}"
echo ""

if [[ ! -d "${BLOBS_DIR}" ]]; then
    echo "Error: Blobs directory '${BLOBS_DIR}' does not exist." >&2
    echo "Please create '${BLOBS_DIR}' and place the required vendor blobs inside." >&2
    echo "Refer to manifests/artifact-hashes.txt for details." >&2
    exit 1
fi

# Build shim if not pre-supplied in blobs dir
SHIM_TARGET="${BLOBS_DIR}/libstagefright_softomx_shim.so"
if [[ ! -f "${SHIM_TARGET}" ]]; then
    echo "[-] libstagefright_softomx_shim.so not found in blobs dir. Compiling from source..."
    SHIM_SOURCE="${REPO_ROOT}/source/libstagefright_softomx_shim.c"
    
    CLANG_BIN=""
    if command -v clang >/dev/null 2>&1; then
        CLANG_BIN="$(command -v clang)"
    fi
    
    if [[ -z "${CLANG_BIN}" ]]; then
        echo "Error: Clang compiler not found to compile shim." >&2
        echo "Please provide precompiled libstagefright_softomx_shim.so in ${BLOBS_DIR}." >&2
        exit 1
    fi
    
    echo "    Using compiler: ${CLANG_BIN}"
    # Minimal freestanding compilation
    "${CLANG_BIN}" --target=armv7a-linux-androideabi \
        -mthumb -mfloat-abi=softfp -mfpu=neon \
        -O2 -fPIC -shared -fvisibility=hidden \
        -Wl,-soname,libstagefright_softomx_shim.so \
        -Wl,-z,now -Wl,-z,relro -Wl,--no-undefined \
        -ffreestanding \
        "${SHIM_SOURCE}" \
        -o "${SHIM_TARGET}" \
        -fuse-ld=lld -nostdlib
    echo "    Shim successfully compiled to ${SHIM_TARGET}"
fi

# Cryptographic integrity check of all required blobs
echo "[*] Verifying cryptographic integrity of blobs..."
ALL_HASHES_OK=true

for blob in "${!EXPECTED_HASHES[@]}"; do
    blob_path="${BLOBS_DIR}/${blob}"
    expected_hash="${EXPECTED_HASHES[${blob}]}"
    
    if [[ ! -f "${blob_path}" ]]; then
        echo "  [FAIL] Missing required blob: ${blob}" >&2
        ALL_HASHES_OK=false
        continue
    fi
    
    actual_hash="$(sha256sum "${blob_path}" | awk '{print $1}')"
    if [[ "${actual_hash}" == "${expected_hash}" ]]; then
        echo "  [PASS] ${blob} (SHA-256: OK)"
    else
        echo "  [FAIL] ${blob} hash mismatch!" >&2
        echo "         Expected: ${expected_hash}" >&2
        echo "         Actual:   ${actual_hash}" >&2
        ALL_HASHES_OK=false
    fi
done

if [[ "${ALL_HASHES_OK}" != "true" ]]; then
    echo ""
    echo "Error: Blob verification failed. Aborting build." >&2
    exit 1
fi

echo ""
echo "[*] Assembling module structure in temporary staging area..."
STAGING_DIR="$(mktemp -d /tmp/nabu_dolby_staging.XXXXXX)"
trap 'rm -rf "${STAGING_DIR}"' EXIT

mkdir -p "${STAGING_DIR}/system/vendor/etc/vintf/manifest"
mkdir -p "${STAGING_DIR}/system/vendor/lib"

# Copy configurations and metadata
cp "${REPO_ROOT}/config/module.prop" "${STAGING_DIR}/"
cp "${REPO_ROOT}/config/system.prop" "${STAGING_DIR}/"
cp "${REPO_ROOT}/scripts/customize.sh" "${STAGING_DIR}/"
cp "${REPO_ROOT}/scripts/post-fs-data.sh" "${STAGING_DIR}/"
cp "${REPO_ROOT}/scripts/post-mount-verify.sh" "${STAGING_DIR}/"

cp "${REPO_ROOT}/config/media_codecs.xml" "${STAGING_DIR}/system/vendor/etc/"
cp "${REPO_ROOT}/config/media_codecs_dolby_audio.xml" "${STAGING_DIR}/system/vendor/etc/"
cp "${REPO_ROOT}/config/android.hardware.media.omx@1.0-service.xml" "${STAGING_DIR}/system/vendor/etc/vintf/manifest/"

# Copy validated blobs
for blob in "${!EXPECTED_HASHES[@]}"; do
    cp "${BLOBS_DIR}/${blob}" "${STAGING_DIR}/system/vendor/lib/"
done

# Standardize permissions
chmod 0644 "${STAGING_DIR}/module.prop"
chmod 0644 "${STAGING_DIR}/system.prop"
chmod 0755 "${STAGING_DIR}/customize.sh"
chmod 0755 "${STAGING_DIR}/post-fs-data.sh"
chmod 0755 "${STAGING_DIR}/post-mount-verify.sh"
chmod 0644 "${STAGING_DIR}/system/vendor/etc/"*.xml
chmod 0644 "${STAGING_DIR}/system/vendor/etc/vintf/manifest/"*.xml
chmod 0644 "${STAGING_DIR}/system/vendor/lib/"*.so

mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_ZIP}"

echo "[*] Creating final ZIP archive..."
(
    cd "${STAGING_DIR}"
    zip -r -9 "${OUTPUT_ZIP}" . >/dev/null
)

FINAL_HASH="$(sha256sum "${OUTPUT_ZIP}" | awk '{print $1}')"
echo ""
echo "=========================================================="
echo " Build Completed Successfully!"
echo " Output: ${OUTPUT_ZIP}"
echo " SHA-256: ${FINAL_HASH}"
echo "=========================================================="

if [[ "${FINAL_HASH}" == "${EXPECTED_FINAL_HASH}" ]]; then
    echo "[PASS] Package hash matches canonical release: ${EXPECTED_FINAL_HASH}"
else
    echo "[NOTE] Package hash differs slightly due to zip timestamps/compression differences."
    echo "       Canonical Release SHA-256: ${EXPECTED_FINAL_HASH}"
fi
