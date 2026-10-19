#pragma once

#include <Limelight.h>
#include <SDL.h>

#include <cstdint>

#define MAX_SLICES 4

typedef struct _VIDEO_STATS {
    uint32_t receivedFrames;
    uint32_t decodedFrames;
    uint32_t renderedFrames;
    uint32_t totalFrames;
    uint32_t networkDroppedFrames;
    uint32_t pacerDroppedFrames;
    uint16_t minHostProcessingLatency;
    uint16_t maxHostProcessingLatency;
    uint32_t totalHostProcessingLatency;
    uint32_t framesWithHostProcessingLatency;
    uint64_t totalReassemblyTimeUs;
    uint64_t totalDecodeTimeUs;
    uint64_t totalPacerTimeUs;
    uint64_t totalRenderTimeUs;
    uint32_t lastRtt;
    uint32_t lastRttVariance;
    double totalFps;
    double receivedFps;
    double decodedFps;
    double renderedFps;
    double videoMegabitsPerSec;
    uint64_t measurementStartUs;
} VIDEO_STATS, *PVIDEO_STATS;

enum class VideoDecoderSelection {
    Auto,
    ForceHardware,
    ForceSoftware,
};

typedef struct _DECODER_PARAMETERS {
    SDL_Window* window;
    VideoDecoderSelection vds;
    int videoFormat;
    int width;
    int height;
    int frameRate;
    bool enableVsync;
    bool testOnly;
} DECODER_PARAMETERS, *PDECODER_PARAMETERS;

#define WINDOW_STATE_CHANGE_SIZE 0x01
#define WINDOW_STATE_CHANGE_DISPLAY 0x02

typedef struct _WINDOW_STATE_CHANGE_INFO {
    SDL_Window* window;
    uint32_t stateChangeFlags;
    int width;
    int height;
    int displayIndex;
} WINDOW_STATE_CHANGE_INFO, *PWINDOW_STATE_CHANGE_INFO;

class IVideoDecoder {
public:
    virtual ~IVideoDecoder() {}
    virtual bool initialize(PDECODER_PARAMETERS params) = 0;
    virtual bool isHardwareAccelerated() = 0;
    virtual int getDecoderCapabilities() = 0;
    virtual int getDecoderColorspace() = 0;
    virtual int getDecoderColorRange() = 0;
    virtual int submitDecodeUnit(PDECODE_UNIT du) = 0;
    virtual bool notifyWindowChanged(PWINDOW_STATE_CHANGE_INFO info) = 0;
};
