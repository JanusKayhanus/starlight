#pragma once

#include <SDL.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/pixdesc.h>
}

#include "decoder.h"

#define RENDERER_ATTRIBUTE_FULLSCREEN_ONLY 0x01
#define RENDERER_ATTRIBUTE_1080P_MAX 0x02
#define RENDERER_ATTRIBUTE_HDR_SUPPORT 0x04
#define RENDERER_ATTRIBUTE_NO_BUFFERING 0x08
#define RENDERER_ATTRIBUTE_FORCE_PACING 0x10

class IFFmpegRenderer {
public:
    enum class RendererType {
        Unknown,
        SDL,
        VideoToolbox,
    };

    enum class InitFailureReason {
        Unknown,
        NoHardwareSupport,
        NoSoftwareSupport,
    };

    virtual ~IFFmpegRenderer() {}

    RendererType getRendererType() const {
        return m_Type;
    }

    const char* getRendererName() const {
        switch (m_Type) {
        case RendererType::SDL:
            return "SDL";
        case RendererType::VideoToolbox:
            return "VideoToolbox";
        default:
            return "Unknown";
        }
    }

    InitFailureReason getInitFailureReason() const {
        return m_InitFailureReason;
    }

    virtual bool initialize(PDECODER_PARAMETERS params) = 0;
    virtual bool prepareDecoderContext(AVCodecContext* context, AVDictionary** options) = 0;
    virtual void renderFrame(AVFrame* frame) = 0;

    virtual bool isRenderThreadSupported() {
        return true;
    }

    virtual bool isDirectRenderingSupported() {
        return true;
    }

    virtual AVPixelFormat getPreferredPixelFormat(int videoFormat) {
        if (videoFormat & VIDEO_FORMAT_MASK_10BIT) {
            return (videoFormat & VIDEO_FORMAT_MASK_YUV444) ?
                AV_PIX_FMT_YUV444P10 : AV_PIX_FMT_P010;
        }
        return (videoFormat & VIDEO_FORMAT_MASK_YUV444) ?
            AV_PIX_FMT_YUV444P : AV_PIX_FMT_YUV420P;
    }

    virtual bool isPixelFormatSupported(int videoFormat, AVPixelFormat pixelFormat) {
        return getPreferredPixelFormat(videoFormat) == pixelFormat;
    }

    virtual bool prepareDecoderContextInGetFormat(AVCodecContext*, AVPixelFormat) {
        return true;
    }

    virtual bool testRenderFrame(AVFrame*) {
        return true;
    }

    virtual bool notifyWindowChanged(PWINDOW_STATE_CHANGE_INFO) {
        return false;
    }

    virtual void prepareToRender() {
    }

    virtual void cleanupRenderContext() {
    }

    virtual int getRendererAttributes() {
        return 0;
    }

    virtual int getDecoderCapabilities() {
        return 0;
    }

    virtual int getDecoderColorspace() {
        return COLORSPACE_REC_709;
    }

    virtual int getDecoderColorRange() {
        return COLOR_RANGE_LIMITED;
    }

    static bool isFrameFullRange(const AVFrame* frame) {
        return frame->color_range == AVCOL_RANGE_JPEG;
    }

    static int getFrameColorspace(const AVFrame* frame) {
        switch (frame->colorspace) {
        case AVCOL_SPC_BT709:
            return COLORSPACE_REC_709;
        case AVCOL_SPC_BT2020_NCL:
        case AVCOL_SPC_BT2020_CL:
            return COLORSPACE_REC_2020;
        default:
            return COLORSPACE_REC_601;
        }
    }

    AVPixelFormat getFrameSwPixelFormat(const AVFrame* frame) {
        if (frame->hw_frames_ctx) {
            return ((AVHWFramesContext*)frame->hw_frames_ctx->data)->sw_format;
        }
        return (AVPixelFormat)frame->format;
    }

    bool hasFrameFormatChanged(const AVFrame* frame) {
        AVPixelFormat format = getFrameSwPixelFormat(frame);
        if (frame->width == m_LastFrameWidth &&
            frame->height == m_LastFrameHeight &&
            format == m_LastFramePixelFormat &&
            frame->color_range == m_LastColorRange &&
            frame->color_primaries == m_LastColorPrimaries &&
            frame->color_trc == m_LastColorTrc &&
            frame->colorspace == m_LastColorSpace &&
            frame->chroma_location == m_LastChromaLocation) {
            return false;
        }

        m_LastFrameWidth = frame->width;
        m_LastFrameHeight = frame->height;
        m_LastFramePixelFormat = format;
        m_LastColorRange = frame->color_range;
        m_LastColorPrimaries = frame->color_primaries;
        m_LastColorTrc = frame->color_trc;
        m_LastColorSpace = frame->colorspace;
        m_LastChromaLocation = frame->chroma_location;
        return true;
    }

protected:
    IFFmpegRenderer(RendererType type) : m_Type(type) {}

    InitFailureReason m_InitFailureReason = InitFailureReason::Unknown;

private:
    RendererType m_Type;
    int m_LastFrameWidth = 0;
    int m_LastFrameHeight = 0;
    AVPixelFormat m_LastFramePixelFormat = AV_PIX_FMT_NONE;
    AVColorRange m_LastColorRange = AVCOL_RANGE_UNSPECIFIED;
    AVColorPrimaries m_LastColorPrimaries = AVCOL_PRI_UNSPECIFIED;
    AVColorTransferCharacteristic m_LastColorTrc = AVCOL_TRC_UNSPECIFIED;
    AVColorSpace m_LastColorSpace = AVCOL_SPC_UNSPECIFIED;
    AVChromaLocation m_LastChromaLocation = AVCHROMA_LOC_UNSPECIFIED;
};
