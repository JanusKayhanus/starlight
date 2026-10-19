#pragma once

class StreamingPreferences
{
public:
    static StreamingPreferences* get();

    static int getDefaultBitrate(int width, int height, int fps, bool yuv444);

    void reload();

    enum AudioConfig
    {
        AC_STEREO,
        AC_51_SURROUND,
        AC_71_SURROUND
    };

    enum VideoCodecConfig
    {
        VCC_AUTO,
        VCC_FORCE_H264,
        VCC_FORCE_HEVC,
        VCC_FORCE_HEVC_HDR_DEPRECATED, // Kept for backwards compatibility
        VCC_FORCE_AV1
    };

    enum VideoDecoderSelection
    {
        VDS_AUTO,
        VDS_FORCE_HARDWARE,
        VDS_FORCE_SOFTWARE
    };

    // macOS renderer selection
    enum RendererSelection
    {
        RS_PROBE_ONLY = -1, // Only valid for probing decoder properties
        RS_AUTO,
        RS_METAL,
        RS_AVSBDL
    };

    enum WindowMode
    {
        WM_FULLSCREEN,
        WM_FULLSCREEN_DESKTOP,
        WM_WINDOWED
    };

    enum UIDisplayMode
    {
        UI_WINDOWED,
        UI_MAXIMIZED,
        UI_FULLSCREEN
    };

    enum CaptureSysKeysMode
    {
        CSK_OFF,
        CSK_FULLSCREEN,
        CSK_ALWAYS,
    };

    // Mac only (for now). Trades presentation latency for smoother frame
    // delivery by tuning the Metal renderer's drawable pool size and its
    // display link frame latency target.
    enum FrameLatencyMode
    {
        FLM_DEFAULT,  // Renderer defaults (lowest latency, unchanged behavior)
        FLM_FAST,     // Less buffering for the lowest possible latency
        FLM_BALANCED, // A little slack to absorb jitter
        FLM_SMOOTH    // Most slack for the steadiest frame delivery
    };

    // Directly accessible members for preferences
    int width;
    int height;
    int fps;
    int bitrateKbps;
    bool unlockBitrate;
    bool autoAdjustBitrate;
    bool enableVsync;
    bool gameOptimizations;
    bool playAudioOnHost;
    bool multiController;
    bool enableMdns;
    bool quitAppAfter;
    bool absoluteMouseMode;
    bool absoluteTouchMode;
    bool framePacing;
    bool connectionWarnings;
    bool configurationWarnings;
    bool richPresence;
    bool gamepadMouse;
    bool detectNetworkBlocking;
    bool showPerformanceOverlay;
    bool swapMouseButtons;
    bool muteOnFocusLoss;
    bool backgroundGamepad;
    bool reverseScrollDirection;
    bool swapFaceButtons;
    bool keepAwake;
    bool disableAwdl;
    int packetSize;
    AudioConfig audioConfig;
    VideoCodecConfig videoCodecConfig;
    bool enableHdr;
    bool enableYUV444;
    VideoDecoderSelection videoDecoderSelection;
    WindowMode windowMode;
    WindowMode recommendedFullScreenMode;
    UIDisplayMode uiDisplayMode;
    CaptureSysKeysMode captureSysKeysMode;
    RendererSelection rendererSelection;
    FrameLatencyMode frameLatencyMode;

    // Runtime-only: display index to start the stream on (-1 = main display).
    // Not persisted; set by the --display command line option.
    int startDisplay;

private:
    StreamingPreferences();
};
