#include "cli.h"
#include "path.h"
#include "serverinfo.h"
#include "settings.h"
#include "settings/streamingpreferences.h"
#include "streaming/session.h"

#include <SDL.h>

#include <cstdio>
#include <string>

int main(int argc, char** argv)
{
    Path::initialize();

    // Handle the "pair" subcommand before anything else so it can run against a
    // host that isn't paired (or reachable) yet.
    int pairExitCode = 0;
    if (handlePairCommandIfPresent(argc, argv, pairExitCode)) {
        return pairExitCode;
    }

    // Parse the command line before doing any network or SDL work so that
    // --help and invalid options don't need a reachable host.
    StreamingPreferences* preferences = StreamingPreferences::get();

    std::string error;
    bool shouldExit = false;
    if (!applyCommandLineOverrides(argc, argv, preferences, shouldExit, error)) {
        fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    if (shouldExit) {
        return 0;
    }

    HostConfig host;
    ClientConfig client;
    if (!loadMoonlightSettings(host, client, error)) {
        fprintf(stderr, "Settings error: %s\n", error.c_str());
        return 1;
    }

    // Allow the display to sleep by default. We will manually use
    // SDL_DisableScreenSaver() and SDL_EnableScreenSaver() while streaming.
    // This hint must be set before initializing the SDL video subsystem.
    SDL_SetHint(SDL_HINT_VIDEO_ALLOW_SCREENSAVER, "1");

    if (SDL_InitSubSystem(SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL_InitSubSystem(SDL_INIT_TIMER) failed: %s\n", SDL_GetError());
        return 1;
    }

    // Avoid the default behavior of changing the timer resolution to 1 ms.
    // We set it manually when we start streaming.
    SDL_SetHint(SDL_HINT_TIMER_RESOLUTION, "0");

    // Disable minimize on focus loss by default. Users seem to want this off by default.
    SDL_SetHint(SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS, "0");

    // Use button labels rather than position labels for gamepads.
    SDL_SetHint(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS, "0");

    // Disable relative mouse scaling to renderer size or logical DPI. We want to send
    // the raw relative motion to the host.
    SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_SCALING, "0");

    // Set our app name for SDL. On SDL 2.0.18+, SDL_APP_NAME is also used for
    // the audio device name.
    SDL_SetHint(SDL_HINT_AUDIO_DEVICE_APP_NAME, "Moonlight");
    SDL_SetHint(SDL_HINT_APP_NAME, "Moonlight");

    if (!fetchServerInfo(host, client, error)) {
        fprintf(stderr, "serverinfo failed: %s\n", error.c_str());
        SDL_Quit();
        return 1;
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Streaming %s from %s at %dx%dx%d, %d kbps (HDR: %s, YUV 4:4:4: %s)",
                host.appName.c_str(), host.name.c_str(),
                preferences->width, preferences->height, preferences->fps,
                preferences->bitrateKbps,
                preferences->enableHdr ? "on" : "off",
                preferences->enableYUV444 ? "on" : "off");

    Session session(&host, &client, preferences);
    if (!session.initialize()) {
        fprintf(stderr, "Unable to initialize the streaming session\n");
        SDL_Quit();
        return 1;
    }

    session.start();

    SDL_Quit();
    return session.wasSuccessful() ? 0 : 1;
}
