/*
 * libstagefright_softomx_shim.c
 *
 * Minimal Pure-C Compatibility Shim for SoftOMX on Xiaomi Pad 5 (nabu)
 * Target OS: DerpFest 17 (Android 17 / API 37)
 *
 * Bridges legacy GraphicBufferMapper 7-parameter lock and 2-parameter unlock
 * exported by DerpFest 17 /vendor/lib/libui.so to satisfy Android 13 HyperOS
 * vendor binary libstagefright_softomx.so relocations.
 *
 * Source hygiene: Uses standard C identifiers mapped to mangled C++ ELF symbols
 * via explicit GCC/Clang assembler labels (__asm__).
 */

#include <stdint.h>

#define STATUS_OK          0
#define STATUS_BAD_VALUE (-22)
#define STATUS_ENOSYS    (-38)
#define NULL ((void *)0)

/* Android Rect definition matching AOSP ui::Rect */
struct ARect {
    int32_t left;
    int32_t top;
    int32_t right;
    int32_t bottom;
};

/*
 * Modern GraphicBufferMapper symbols imported from /vendor/lib/libui.so
 *
 * Explicit assembler labels bind standard C function names to their
 * respective C++ mangled symbols in .dynsym:
 * - modern_mapper_lock   -> _ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv
 * - modern_mapper_unlock -> _ZN7android19GraphicBufferMapper6unlockEPK13native_handlePNS_4base14unique_fd_implINS4_13DefaultCloserEEE
 */
__attribute__((visibility("default")))
extern int32_t modern_mapper_lock(
    void *this_ptr,
    const void *handle,
    uint32_t usage,
    const struct ARect *bounds,
    void **vaddr
) __asm__("_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv");

__attribute__((visibility("default")))
extern int32_t modern_mapper_unlock(
    void *this_ptr,
    const void *handle,
    void *fenceOut
) __asm__("_ZN7android19GraphicBufferMapper6unlockEPK13native_handlePNS_4base14unique_fd_implINS4_13DefaultCloserEEE");

/*
 * Legacy GraphicBufferMapper symbols exported for libstagefright_softomx.so
 *
 * Explicit assembler labels bind standard C function names to their
 * respective legacy C++ mangled symbols in .dynsym:
 * - shim_legacy_lock   -> _ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_
 * - shim_legacy_unlock -> _ZN7android19GraphicBufferMapper6unlockEPK13native_handle
 */

__attribute__((visibility("default")))
int32_t shim_legacy_lock(
    void *this_ptr,
    const void *handle,
    uint32_t usage,
    const struct ARect *bounds,
    void **vaddr,
    int32_t *outBytesPerPixel,
    int32_t *outBytesPerStride
) __asm__("_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPvPiS9_");

int32_t shim_legacy_lock(
    void *this_ptr,
    const void *handle,
    uint32_t usage,
    const struct ARect *bounds,
    void **vaddr,
    int32_t *outBytesPerPixel,
    int32_t *outBytesPerStride
) {
    /* Parameter validation */
    if (this_ptr == NULL || handle == NULL || bounds == NULL || vaddr == NULL) {
        return STATUS_BAD_VALUE;
    }

    /*
     * Fail-closed contract: If caller requests plane layout calculation
     * (non-NULL outBytesPerPixel or outBytesPerStride), return -ENOSYS
     * without executing lock to avoid corrupting caller assumptions.
     */
    if (outBytesPerPixel != NULL || outBytesPerStride != NULL) {
        return STATUS_ENOSYS;
    }

    /* Forward to 4-parameter modern lock */
    return modern_mapper_lock(
        this_ptr,
        handle,
        usage,
        bounds,
        vaddr
    );
}

__attribute__((visibility("default")))
int32_t shim_legacy_unlock(
    void *this_ptr,
    const void *handle
) __asm__("_ZN7android19GraphicBufferMapper6unlockEPK13native_handle");

int32_t shim_legacy_unlock(
    void *this_ptr,
    const void *handle
) {
    /* Parameter validation */
    if (this_ptr == NULL || handle == NULL) {
        return STATUS_BAD_VALUE;
    }

    /*
     * Forward to modern unlock with fenceOut = NULL.
     * The mapper will block until GPU work finishes or manage sync internally.
     */
    return modern_mapper_unlock(
        this_ptr,
        handle,
        NULL
    );
}
