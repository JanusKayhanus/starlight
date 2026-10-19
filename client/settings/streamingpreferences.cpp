#include "streamingpreferences.h"

#include "cfprefs.h"

#include <cmath>
#include <cstdlib>

#define SER_WIDTH "width"
#define SER_HEIGHT "height"
#define SER_FPS "fps"
#define SER_BITRATE "bitrate"
#define SER_UNLOCK_BITRATE "unlockbitrate"
#define SER_AUTOADJUSTBITRATE "autoadjustbitrate"
#define SER_FULLSCREEN "fullscreen"
#define SER_VSYNC "vsync"
#define SER_GAMEOPTS "gameopts"
#define SER_HOSTAUDIO "hostaudio"
#define SER_MULTICONT "multicontroller"
#define SER_AUDIOCFG "audiocfg"
#define SER_VIDEOCFG "videocfg"
#define SER_HDR "hdr"
#define SER_YUV444 "yuv444"
#define SER_VIDEODEC "videodec"
#define SER_WINDOWMODE "windowmode"
#define SER_MDNS "mdns"
#define SER_QUITAPPAFTER "quitAppAfter"
#define SER_ABSMOUSEMODE "mouseacceleration"
#define SER_ABSTOUCHMODE "abstouchmode"
#define SER_STARTWINDOWED "startwindowed"
#define SER_FRAMEPACING "framepacing"
#define SER_CONNWARNINGS "connwarnings"
#define SER_CONFWARNINGS "confwarnings"
#define SER_UIDISPLAYMODE "uidisplaymode"
#define SER_RICHPRESENCE "richpresence"
#define SER_GAMEPADMOUSE "gamepadmouse"
#define SER_DEFAULTVER "defaultver"
#define SER_PACKETSIZE "packetsize"
#define SER_DETECTNETBLOCKING "detectnetblocking"
#define SER_SHOWPERFOVERLAY "showperfoverlay"
#define SER_SWAPMOUSEBUTTONS "swapmousebuttons"
#define SER_MUTEONFOCUSLOSS "muteonfocusloss"
#define SER_BACKGROUNDGAMEPAD "backgroundgamepad"
#define SER_REVERSESCROLL "reversescroll"
#define SER_SWAPFACEBUTTONS "swapfacebuttons"
#define SER_CAPTURESYSKEYS "capturesyskeys"
#define SER_KEEPAWAKE "keepawake"
#define SER_DISABLEAWDL "disableawdl"
#define SER_RENDERER "renderer"
#define SER_FRAMELATENCY "framelatency"

#define CURRENT_DEFAULT_VER 2

static StreamingPreferences* s_GlobalPrefs;

StreamingPreferences::StreamingPreferences()
{
    reload();
}

StreamingPreferences* StreamingPreferences::get()
{
    if (s_GlobalPrefs == nullptr) {
        s_GlobalPrefs = new StreamingPreferences();
    }
    return s_GlobalPrefs;
}

void StreamingPreferences::reload()
{
    int defaultVer = CfPrefs::copyInt(SER_DEFAULTVER, 0);

    recommendedFullScreenMode = WindowMode::WM_FULLSCREEN_DESKTOP;

    width = CfPrefs::copyInt(SER_WIDTH, 1920);
    height = CfPrefs::copyInt(SER_HEIGHT, 1080);
    fps = CfPrefs::copyInt(SER_FPS, 60);
    enableYUV444 = CfPrefs::copyBool(SER_YUV444, false);
    bitrateKbps = CfPrefs::copyInt(SER_BITRATE, getDefaultBitrate(width, height, fps, enableYUV444));
    unlockBitrate = CfPrefs::copyBool(SER_UNLOCK_BITRATE, false);
    autoAdjustBitrate = CfPrefs::copyBool(SER_AUTOADJUSTBITRATE, true);
    enableVsync = CfPrefs::copyBool(SER_VSYNC, true);
    gameOptimizations = CfPrefs::copyBool(SER_GAMEOPTS, true);
    playAudioOnHost = CfPrefs::copyBool(SER_HOSTAUDIO, false);
    multiController = CfPrefs::copyBool(SER_MULTICONT, true);
    enableMdns = CfPrefs::copyBool(SER_MDNS, true);
    quitAppAfter = CfPrefs::copyBool(SER_QUITAPPAFTER, false);
    absoluteMouseMode = CfPrefs::copyBool(SER_ABSMOUSEMODE, false);
    absoluteTouchMode = CfPrefs::copyBool(SER_ABSTOUCHMODE, true);
    framePacing = CfPrefs::copyBool(SER_FRAMEPACING, false);
    connectionWarnings = CfPrefs::copyBool(SER_CONNWARNINGS, true);
    configurationWarnings = CfPrefs::copyBool(SER_CONFWARNINGS, true);
    richPresence = CfPrefs::copyBool(SER_RICHPRESENCE, true);
    gamepadMouse = CfPrefs::copyBool(SER_GAMEPADMOUSE, true);
    detectNetworkBlocking = CfPrefs::copyBool(SER_DETECTNETBLOCKING, true);
    showPerformanceOverlay = CfPrefs::copyBool(SER_SHOWPERFOVERLAY, false);
    packetSize = CfPrefs::copyInt(SER_PACKETSIZE, 0);
    swapMouseButtons = CfPrefs::copyBool(SER_SWAPMOUSEBUTTONS, false);
    muteOnFocusLoss = CfPrefs::copyBool(SER_MUTEONFOCUSLOSS, false);
    backgroundGamepad = CfPrefs::copyBool(SER_BACKGROUNDGAMEPAD, false);
    reverseScrollDirection = CfPrefs::copyBool(SER_REVERSESCROLL, false);
    swapFaceButtons = CfPrefs::copyBool(SER_SWAPFACEBUTTONS, false);
    keepAwake = CfPrefs::copyBool(SER_KEEPAWAKE, true);
    disableAwdl = CfPrefs::copyBool(SER_DISABLEAWDL, true);
    enableHdr = CfPrefs::copyBool(SER_HDR, false);
    captureSysKeysMode = static_cast<CaptureSysKeysMode>(CfPrefs::copyInt(SER_CAPTURESYSKEYS,
                                                         static_cast<int>(CaptureSysKeysMode::CSK_OFF)));
    audioConfig = static_cast<AudioConfig>(CfPrefs::copyInt(SER_AUDIOCFG,
                                                  static_cast<int>(AudioConfig::AC_STEREO)));
    videoCodecConfig = static_cast<VideoCodecConfig>(CfPrefs::copyInt(SER_VIDEOCFG,
                                                  static_cast<int>(VideoCodecConfig::VCC_AUTO)));
    videoDecoderSelection = static_cast<VideoDecoderSelection>(CfPrefs::copyInt(SER_VIDEODEC,
                                                  static_cast<int>(VideoDecoderSelection::VDS_AUTO)));
    rendererSelection = static_cast<RendererSelection>(CfPrefs::copyInt(SER_RENDERER,
                                                  static_cast<int>(RendererSelection::RS_AUTO)));
    frameLatencyMode = static_cast<FrameLatencyMode>(CfPrefs::copyInt(SER_FRAMELATENCY,
                                                  static_cast<int>(FrameLatencyMode::FLM_DEFAULT)));
    windowMode = static_cast<WindowMode>(CfPrefs::copyInt(SER_WINDOWMODE,
                                                        // Try to load from the old preference value too
                                                        static_cast<int>(CfPrefs::copyBool(SER_FULLSCREEN, true) ?
                                                                             recommendedFullScreenMode : WindowMode::WM_WINDOWED)));
    startDisplay = -1;

    uiDisplayMode = static_cast<UIDisplayMode>(CfPrefs::copyInt(SER_UIDISPLAYMODE,
                                               static_cast<int>(CfPrefs::copyBool(SER_STARTWINDOWED, true) ? UIDisplayMode::UI_WINDOWED
                                                                                                                 : UIDisplayMode::UI_MAXIMIZED)));

    // Perform default settings updates as required based on last default version
    if (defaultVer < 1) {
        // Update window mode setting from full-screen (old default) to borderless windowed (new default)
        if (windowMode == WindowMode::WM_FULLSCREEN) {
            windowMode = WindowMode::WM_FULLSCREEN_DESKTOP;
        }
    }

    // Fixup VCC value to the new settings format with codec and HDR separate
    if (videoCodecConfig == VCC_FORCE_HEVC_HDR_DEPRECATED) {
        videoCodecConfig = VCC_AUTO;
        enableHdr = true;
    }
}

int StreamingPreferences::getDefaultBitrate(int width, int height, int fps, bool yuv444)
{
    // Don't scale bitrate linearly beyond 60 FPS. It's definitely not a linear
    // bitrate increase for frame rate once we get to values that high.
    float frameRateFactor = (fps <= 60 ? fps : (sqrt(fps / 60.f) * 60.f)) / 30.f;

    // TODO: Collect some empirical data to see if these defaults make sense.
    // We're just using the values that the Shield used, as we have for years.
    static const struct resTable {
        int pixels;
        int factor;
    } resTable[] {
        { 640 * 360, 1 },
        { 854 * 480, 2 },
        { 1280 * 720, 5 },
        { 1920 * 1080, 10 },
        { 2560 * 1440, 20 },
        { 3840 * 2160, 40 },
        { -1, -1 },
    };

    // Calculate the resolution factor by linear interpolation of the resolution table
    float resolutionFactor;
    int pixels = width * height;
    for (int i = 0;; i++) {
        if (pixels == resTable[i].pixels) {
            // We can bail immediately for exact matches
            resolutionFactor = resTable[i].factor;
            break;
        }
        else if (pixels < resTable[i].pixels) {
            if (i == 0) {
                // Never go below the lowest resolution entry
                resolutionFactor = resTable[i].factor;
            }
            else {
                // Interpolate between the entry greater than the chosen resolution (i) and the entry less than the chosen resolution (i-1)
                resolutionFactor = ((float)(pixels - resTable[i-1].pixels) / (resTable[i].pixels - resTable[i-1].pixels)) * (resTable[i].factor - resTable[i-1].factor) + resTable[i-1].factor;
            }
            break;
        }
        else if (resTable[i].pixels == -1) {
            // Never go above the highest resolution entry
            resolutionFactor = resTable[i-1].factor;
            break;
        }
    }

    if (yuv444) {
        // This is rough estimation based on the fact that 4:4:4 doubles the amount of raw YUV data compared to 4:2:0
        resolutionFactor *= 2;
    }

    return (int)lround(resolutionFactor * frameRateFactor) * 1000;
}
