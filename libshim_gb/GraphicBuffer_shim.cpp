/*
 * TAB-A03-BS / Android 7 GPU shim.
 *
 * The Marvell 5.1-era HWComposer blob (/system/lib64/libHWComposerGC.so, pulled
 * in by hwcomposer.mrvl.so) references the pre-N GraphicBuffer constructor
 *   android::GraphicBuffer::GraphicBuffer(uint32_t w, uint32_t h,
 *                                         PixelFormat format, uint32_t usage)
 * i.e. the mangled symbol _ZN7android13GraphicBufferC1Ejjij (and its C2 base
 * variant). Android N removed that form in favour of a 5-argument constructor
 * that appends a std::string requestorName, so SurfaceFlinger's dlopen of the
 * HWC HAL fails with "cannot locate symbol ... _ZN7android13GraphicBufferC1Ejjij"
 * and falls back to GLES composition with software vsync -> visible flicker.
 *
 * This shim re-exports the old symbols and placement-constructs the object with
 * the modern 5-arg constructor, supplying a fixed requestorName. It is injected
 * into surfaceflinger via LD_PRELOAD so the symbol is in the global scope when
 * libHWComposerGC.so is resolved.
 */
#include <ui/GraphicBuffer.h>
#include <new>
#include <string>

using android::GraphicBuffer;
using android::PixelFormat;

extern "C" {

GraphicBuffer* _ZN7android13GraphicBufferC1Ejjij(
        GraphicBuffer* thisptr, uint32_t w, uint32_t h,
        int32_t format, uint32_t usage) {
    new (thisptr) GraphicBuffer(w, h, static_cast<PixelFormat>(format), usage,
                                std::string("shim_hwc"));
    return thisptr;
}

GraphicBuffer* _ZN7android13GraphicBufferC2Ejjij(
        GraphicBuffer* thisptr, uint32_t w, uint32_t h,
        int32_t format, uint32_t usage) {
    new (thisptr) GraphicBuffer(w, h, static_cast<PixelFormat>(format), usage,
                                std::string("shim_hwc"));
    return thisptr;
}

}
