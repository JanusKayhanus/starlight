#pragma once

#include "renderer.h"

extern "C" {
#include <libavutil/hwcontext.h>
}

// Backend renderer that only provisions a VideoToolbox hardware device
// context for FFmpeg. The SDL frontend renderer draws the decoded frames.
class VTRenderer : public IFFmpegRenderer {
public:
    VTRenderer() : IFFmpegRenderer(RendererType::VideoToolbox) {}

    bool initialize(PDECODER_PARAMETERS) override {
        return true;
    }

    bool prepareDecoderContext(AVCodecContext* context, AVDictionary**) override {
        AVBufferRef* deviceContext = nullptr;
        int err = av_hwdevice_ctx_create(&deviceContext, AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
                                         nullptr, nullptr, 0);
        if (err < 0) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "av_hwdevice_ctx_create(VideoToolbox) failed: %d", err);
            return false;
        }

        av_buffer_unref(&context->hw_device_ctx);
        context->hw_device_ctx = deviceContext;
        return true;
    }

    void renderFrame(AVFrame*) override {
        // The SDL frontend owns presentation.
    }

    bool isDirectRenderingSupported() override {
        return false;
    }
};
