#include "macoswindowinfo.h"

#include "SDL_compat.h"

#include <SDL_syswm.h>

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>

void LogStreamWindowInfo(SDL_Window* window, const char* when)
{ @autoreleasepool {
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (window == nullptr || !SDL_GetWindowWMInfo(window, &info) ||
            info.subsystem != SDL_SYSWM_COCOA) {
        return;
    }

    NSWindow* nswindow = info.info.cocoa.window;
    if (nswindow == nil) {
        return;
    }

    NSRect frame = [nswindow frame];
    NSRect content = [[nswindow contentView] frame];
    NSRect screen = [[nswindow screen] frame];

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "[%s] NSWindow frame %.0fx%.0f at %.0f,%.0f, content %.0fx%.0f, "
                "screen %.0fx%.0f, styleMask 0x%lx, level %ld, collectionBehavior 0x%lx, "
                "fullscreen %d, zoomed %d, visible %d",
                when,
                frame.size.width, frame.size.height, frame.origin.x, frame.origin.y,
                content.size.width, content.size.height,
                screen.size.width, screen.size.height,
                (unsigned long)[nswindow styleMask],
                (long)[nswindow level],
                (unsigned long)[nswindow collectionBehavior],
                [nswindow styleMask] & NSWindowStyleMaskFullScreen ? 1 : 0,
                [nswindow isZoomed] ? 1 : 0,
                [nswindow isVisible] ? 1 : 0);
}}

void MacOSConfigureStreamWindow(SDL_Window* window, bool useSpaces)
{ @autoreleasepool {
    // Hide the menu bar and Dock so the video can reach the physical edges of
    // the display. AppKit otherwise reserves the menu bar strip (~30 pt) even
    // while the window is in a fullscreen Space.
    [NSApp setPresentationOptions:(NSApplicationPresentationHideDock |
                                   NSApplicationPresentationHideMenuBar)];

    if (useSpaces) {
        // Presentation options were applied before the fullscreen transition
        // (see Session::exec), which lets AppKit size the fullscreen Space to
        // the full display. Do not touch the frame here: resizing a window
        // while it is entering a Space makes AppKit abort the transition.
        return;
    }

    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (window == nullptr || !SDL_GetWindowWMInfo(window, &info) ||
            info.subsystem != SDL_SYSWM_COCOA) {
        return;
    }

    NSWindow* nswindow = info.info.cocoa.window;

    // SDL puts borderless fullscreen windows at status level with
    // FullScreenAuxiliary behavior, which keeps them out of Mission Control
    // and can constrain them to the visible frame. Use a normal, managed
    // window at the full display bounds instead.
    NSRect screen = [[nswindow screen] frame];

    [nswindow setLevel:NSNormalWindowLevel];
    [nswindow setCollectionBehavior:(NSWindowCollectionBehaviorManaged |
                                      NSWindowCollectionBehaviorParticipatesInCycle)];
    [nswindow setFrame:screen display:YES];
}}

void MacOSRestoreAfterStreaming()
{ @autoreleasepool {
    [NSApp setPresentationOptions:NSApplicationPresentationDefault];
}}
