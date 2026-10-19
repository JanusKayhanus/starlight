#include "cli.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace {

void printUsage()
{
    printf(
        "Usage: Moonlight [options]\n"
        "\n"
        "Streams the Desktop app of the configured host using the saved\n"
        "Moonlight preferences as defaults.\n"
        "\n"
        "Options:\n"
        "  --720 | --1080 | --1440 | --4K   Select a standard resolution\n"
        "  --resolution <width>x<height>    Select a custom resolution\n"
        "  --fps <fps>                      Stream frame rate (10-480)\n"
        "  --bitrate <kbps>                 Video bitrate in Kbps (500-500000)\n"
        "  --hdr / --no-hdr                 Enable or disable HDR streaming\n"
        "  --yuv444 / --no-yuv444           Enable or disable YUV 4:4:4\n"
        "  --video-codec <codec>            auto, h264, hevc, or av1\n"
        "  --display-mode <mode>            fullscreen, borderless, or windowed\n"
        "  --help                           Show this help\n");
}

bool parseResolution(const std::string& value, int& width, int& height)
{
    size_t x = value.find('x');
    if (x == std::string::npos) {
        x = value.find('X');
    }
    if (x == std::string::npos) {
        return false;
    }

    width = atoi(value.substr(0, x).c_str());
    height = atoi(value.substr(x + 1).c_str());
    return width > 0 && height > 0;
}

bool inRange(int value, int min, int max)
{
    return value >= min && value <= max;
}

} // namespace

bool applyCommandLineOverrides(int argc, char** argv,
                               StreamingPreferences* preferences,
                               bool& shouldExit,
                               std::string& error)
{
    bool displaySet = false;
    bool bitrateSet = false;

    shouldExit = false;

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];

        auto nextValue = [&](const char* name) -> std::string {
            if (i + 1 >= argc) {
                error = std::string("Missing value for ") + name;
                return {};
            }
            return argv[++i];
        };

        if (arg == "--help" || arg == "-h") {
            printUsage();
            shouldExit = true;
            return true;
        }
        else if (arg == "--720") {
            preferences->width = 1280;
            preferences->height = 720;
            displaySet = true;
        }
        else if (arg == "--1080") {
            preferences->width = 1920;
            preferences->height = 1080;
            displaySet = true;
        }
        else if (arg == "--1440") {
            preferences->width = 2560;
            preferences->height = 1440;
            displaySet = true;
        }
        else if (arg == "--4K") {
            preferences->width = 3840;
            preferences->height = 2160;
            displaySet = true;
        }
        else if (arg == "--resolution") {
            std::string value = nextValue("--resolution");
            if (value.empty()) {
                return false;
            }

            if (!parseResolution(value, preferences->width, preferences->height) ||
                    !inRange(preferences->width, 1, 7680) ||
                    !inRange(preferences->height, 1, 7680)) {
                error = "Invalid resolution: " + value;
                return false;
            }
            displaySet = true;
        }
        else if (arg == "--fps") {
            std::string value = nextValue("--fps");
            if (value.empty()) {
                return false;
            }

            int fps = atoi(value.c_str());
            if (!inRange(fps, 10, 480)) {
                error = "FPS must be between 10 and 480";
                return false;
            }
            preferences->fps = fps;
            displaySet = true;
        }
        else if (arg == "--bitrate") {
            std::string value = nextValue("--bitrate");
            if (value.empty()) {
                return false;
            }

            int bitrate = atoi(value.c_str());
            if (!inRange(bitrate, 500, 500000)) {
                error = "Bitrate must be between 500 and 500000 Kbps";
                return false;
            }
            preferences->bitrateKbps = bitrate;
            bitrateSet = true;
        }
        else if (arg == "--hdr") {
            preferences->enableHdr = true;
        }
        else if (arg == "--no-hdr") {
            preferences->enableHdr = false;
        }
        else if (arg == "--yuv444") {
            preferences->enableYUV444 = true;
        }
        else if (arg == "--no-yuv444") {
            preferences->enableYUV444 = false;
        }
        else if (arg == "--video-codec") {
            std::string value = nextValue("--video-codec");
            if (value.empty()) {
                return false;
            }

            if (value == "auto") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_AUTO;
            }
            else if (value == "h264") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_FORCE_H264;
            }
            else if (value == "hevc") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_FORCE_HEVC;
            }
            else if (value == "av1") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_FORCE_AV1;
            }
            else {
                error = "Invalid video codec: " + value;
                return false;
            }
        }
        else if (arg == "--display-mode") {
            std::string value = nextValue("--display-mode");
            if (value.empty()) {
                return false;
            }

            if (value == "fullscreen") {
                preferences->windowMode = StreamingPreferences::WM_FULLSCREEN;
            }
            else if (value == "borderless") {
                preferences->windowMode = StreamingPreferences::WM_FULLSCREEN_DESKTOP;
            }
            else if (value == "windowed") {
                preferences->windowMode = StreamingPreferences::WM_WINDOWED;
            }
            else {
                error = "Invalid display mode: " + value;
                return false;
            }
        }
        else {
            error = "Unknown option: " + arg;
            return false;
        }
    }

    // Match the original client: when the display mode or frame rate changes
    // but the bitrate wasn't explicitly chosen, recompute the default bitrate.
    if (!bitrateSet && displaySet) {
        preferences->bitrateKbps = StreamingPreferences::getDefaultBitrate(
            preferences->width, preferences->height, preferences->fps,
            preferences->enableYUV444);
    }

    return true;
}
