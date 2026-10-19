#pragma once

#include "renderer.h"

#ifdef __OBJC__
#import <Metal/Metal.h>
class VTBaseRenderer : public IFFmpegRenderer {
public:
    VTBaseRenderer(IFFmpegRenderer::RendererType type);
    virtual ~VTBaseRenderer();
    bool checkDecoderCapabilities(id<MTLDevice> device, PDECODER_PARAMETERS params);
    void setHdrMode(bool enabled) override;

protected:
    bool isAppleSilicon();

    bool m_HdrMetadataChanged; // Manual reset
    CFDataRef m_MasteringDisplayColorVolume;
    CFDataRef m_ContentLightLevelInfo;
};
#endif

// A factory is required to avoid pulling in
// incompatible Objective-C headers.

// Exposes platform checks that don't require Objective-C to callers
// (like the renderer selection logic in ffmpeg.cpp).
class VTSystemInfo {
public:
    // Returns true if this process is running on Apple Silicon hardware.
    static bool isAppleSilicon();
};

class VTMetalRendererFactory {
public:
    static
    IFFmpegRenderer* createRenderer(bool hwAccel);
};

class VTRendererFactory {
public:
    static
    IFFmpegRenderer* createRenderer();
};
