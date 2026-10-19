#include "streamutils.h"

#include <SDL.h>

#include <ApplicationServices/ApplicationServices.h>

Uint32 StreamUtils::getPlatformWindowFlags()
{
    return SDL_WINDOW_METAL;
}

SDL_Window* StreamUtils::createTestWindow()
{
    SDL_Window* testWindow;
    Uint32 baseFlags = 0;

    // Stop text input before creating the test window to avoid sdl2-compat
    // starting text input on the new window. This might trigger the IME to
    // be displayed.
    SDL_StopTextInput();

    // Test windows are always hidden
    baseFlags |= SDL_WINDOW_HIDDEN;

    // Try to add the platform-specific flags first and fall back if that fails
    testWindow = SDL_CreateWindow("", 0, 0, 1280, 720,
                                  baseFlags | StreamUtils::getPlatformWindowFlags());
    if (!testWindow) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to create test window with platform flags: %s",
                    SDL_GetError());

        testWindow = SDL_CreateWindow("", 0, 0, 1280, 720, baseFlags);
        if (!testWindow) {
            return nullptr;
        }
    }

    return testWindow;
}

void StreamUtils::scaleSourceToDestinationSurface(SDL_Rect* src, SDL_Rect* dst)
{
    int dstH = SDL_ceilf((float)dst->w * src->h / src->w);
    int dstW = SDL_ceilf((float)dst->h * src->w / src->h);

    if (dstH > dst->h) {
        dst->x += (dst->w - dstW) / 2;
        dst->w = dstW;
    }
    else {
        dst->y += (dst->h - dstH) / 2;
        dst->h = dstH;
    }
}

void StreamUtils::screenSpaceToNormalizedDeviceCoords(SDL_FRect* rect, int viewportWidth, int viewportHeight)
{
    rect->x = (rect->x / (viewportWidth / 2.0f)) - 1.0f;
    rect->y = (rect->y / (viewportHeight / 2.0f)) - 1.0f;
    rect->w = rect->w / (viewportWidth / 2.0f);
    rect->h = rect->h / (viewportHeight / 2.0f);
}

void StreamUtils::screenSpaceToNormalizedDeviceCoords(SDL_Rect* src, SDL_FRect* dst, int viewportWidth, int viewportHeight)
{
    dst->x = ((float)src->x / (viewportWidth / 2.0f)) - 1.0f;
    dst->y = ((float)src->y / (viewportHeight / 2.0f)) - 1.0f;
    dst->w = (float)src->w / (viewportWidth / 2.0f);
    dst->h = (float)src->h / (viewportHeight / 2.0f);
}

int StreamUtils::getDisplayRefreshRate(SDL_Window* window)
{
    int displayIndex = SDL_GetWindowDisplayIndex(window);
    if (displayIndex < 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to get current display: %s",
                     SDL_GetError());

        // Assume display 0 if it fails
        displayIndex = 0;
    }

    SDL_DisplayMode mode;
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN_DESKTOP) == SDL_WINDOW_FULLSCREEN) {
        // Use the window display mode for full-screen exclusive mode
        if (SDL_GetWindowDisplayMode(window, &mode) != 0) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "SDL_GetWindowDisplayMode() failed: %s",
                         SDL_GetError());

            // Assume 60 Hz
            return 60;
        }
    }
    else {
        // Use the current display mode for windowed and borderless
        if (SDL_GetCurrentDisplayMode(displayIndex, &mode) != 0) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "SDL_GetCurrentDisplayMode() failed: %s",
                         SDL_GetError());

            // Assume 60 Hz
            return 60;
        }
    }

    // May be zero if undefined
    if (mode.refresh_rate == 0) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Refresh rate unknown; assuming 60 Hz");
        mode.refresh_rate = 60;
    }

    return mode.refresh_rate;
}

bool StreamUtils::hasFastAes()
{
    // Everything that runs Catalina and later has AES-NI or ARMv8 crypto instructions
    return true;
}

bool StreamUtils::getNativeDesktopMode(int displayIndex, SDL_DisplayMode* mode, SDL_Rect* safeArea)
{
#define MAX_DISPLAYS 16
    CGDirectDisplayID displayIds[MAX_DISPLAYS];
    uint32_t displayCount = 0;
    CGGetActiveDisplayList(MAX_DISPLAYS, displayIds, &displayCount);
    if (displayIndex >= (int)displayCount) {
        return false;
    }

    SDL_zerop(mode);

    // Retina displays have non-native resolutions both below and above (!) their
    // native resolution, so it's impossible for us to figure out what's actually
    // native on macOS using the SDL API alone. We'll talk to CoreGraphics to
    // find the correct resolution and match it in our SDL list.
    CFArrayRef modeList = CGDisplayCopyAllDisplayModes(displayIds[displayIndex], nullptr);
    CFIndex count = CFArrayGetCount(modeList);
    for (CFIndex i = 0; i < count; i++) {
        auto cgMode = (CGDisplayModeRef)(CFArrayGetValueAtIndex(modeList, i));
        if ((CGDisplayModeGetIOFlags(cgMode) & kDisplayModeNativeFlag) != 0) {
            mode->w = static_cast<int>(CGDisplayModeGetWidth(cgMode));
            mode->h = static_cast<int>(CGDisplayModeGetHeight(cgMode));
            break;
        }
    }

    safeArea->x = 0;
    safeArea->y = 0;
    safeArea->w = mode->w;
    safeArea->h = mode->h;

#if TARGET_CPU_ARM64
    // Now that we found the native full-screen mode, let's look for one that matches along
    // the width but not the height and we'll assume that's the safe area full-screen mode.
    //
    // There doesn't appear to be a CG API or flag that will tell us that a given mode
    // is a "safe area" mode, so we have to use our own (brittle) heuristics. :(
    //
    // To avoid potential false positives, let's avoid checking for external displays, since
    // we might have scenarios like a 1920x1200 display with an alternate 1920x1080 mode
    // which would falsely trigger our notch detection here.
    if (CGDisplayIsBuiltin(displayIds[displayIndex])) {
        for (CFIndex i = 0; i < count; i++) {
            auto cgMode = (CGDisplayModeRef)(CFArrayGetValueAtIndex(modeList, i));
            auto cgModeWidth = static_cast<int>(CGDisplayModeGetWidth(cgMode));
            auto cgModeHeight = static_cast<int>(CGDisplayModeGetHeight(cgMode));

            // If the modes differ by more than 100, we'll assume it's not a notch mode
            if (mode->w == cgModeWidth && mode->h != cgModeHeight && mode->h <= cgModeHeight + 100) {
                safeArea->w = cgModeWidth;
                safeArea->h = cgModeHeight;
            }
        }
    }
#endif

    CFRelease(modeList);

    // Special case for probing for notched displays prior to video subsystem initialization
    // in Session::initialize() for Darwin only!
    if (SDL_WasInit(SDL_INIT_VIDEO)) {
        // Now find the SDL mode that matches the CG native mode
        for (int i = 0; i < SDL_GetNumDisplayModes(displayIndex); i++) {
            SDL_DisplayMode thisMode;
            if (SDL_GetDisplayMode(displayIndex, i, &thisMode) == 0) {
                if (thisMode.w == mode->w && thisMode.h == mode->h &&
                    thisMode.refresh_rate >= mode->refresh_rate) {
                    *mode = thisMode;
                    break;
                }
            }
        }
    }
    return true;
}
