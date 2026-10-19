#include "macoscursor.h"

#include <SDL_syswm.h>

#import <Cocoa/Cocoa.h>

static id s_EventMonitor;
static SDL_Window* s_Window;
static SDL_Rect s_Region;
static bool s_TopEdgeOnly;

static bool s_PresentationOptionsOverridden;
static NSApplicationPresentationOptions s_SavedPresentationOptions;

static NSWindow* getNSWindow(SDL_Window* window)
{
    SDL_SysWMinfo info;

    SDL_VERSION(&info.version);
    if (window == nullptr || !SDL_GetWindowWMInfo(window, &info) || info.subsystem != SDL_SYSWM_COCOA) {
        return nil;
    }

    return info.info.cocoa.window;
}

static void clampCursor()
{
    NSWindow* window = getNSWindow(s_Window);
    if (window == nil || !window.isKeyWindow) {
        return;
    }

    // Convert the region from SDL window coordinates (top-left origin) into
    // Cocoa screen coordinates (bottom-left origin of the primary display)
    NSRect content = [window contentRectForFrameRect:window.frame];
    NSRect region = NSMakeRect(NSMinX(content) + s_Region.x,
                               NSMaxY(content) - (s_Region.y + s_Region.h),
                               s_Region.w,
                               s_Region.h);

    // The maximum edges are exclusive, so keep the cursor one point inside them
    NSPoint location = [NSEvent mouseLocation];
    NSPoint clamped = location;
    clamped.y = MIN(clamped.y, NSMaxY(region) - 1);
    if (!s_TopEdgeOnly) {
        clamped.y = MAX(clamped.y, NSMinY(region));
        clamped.x = MIN(MAX(clamped.x, NSMinX(region)), NSMaxX(region) - 1);
    }

    if (NSEqualPoints(location, clamped)) {
        return;
    }

    // CoreGraphics uses a top-left origin relative to the primary display
    CGFloat primaryHeight = NSMaxY(NSScreen.screens.firstObject.frame);
    CGWarpMouseCursorPosition(CGPointMake(clamped.x, primaryHeight - clamped.y));

    // Warping suppresses local mouse events for 250 ms unless we reassociate
    // the mouse and cursor, which makes the edge feel sticky.
    CGAssociateMouseAndMouseCursorPosition(true);
}

static void setMenuBarHidden(NSWindow* window, bool hidden)
{
    @try {
        if (hidden && !s_PresentationOptionsOverridden &&
                window != nil && (window.styleMask & NSWindowStyleMaskFullScreen)) {
            // Disable the auto-hiding menu bar of the fullscreen space, so it doesn't
            // slide down over the stream when the cursor is pushed against the top edge.
            s_SavedPresentationOptions = NSApp.presentationOptions;
            NSApp.presentationOptions = NSApplicationPresentationFullScreen |
                                        NSApplicationPresentationHideDock |
                                        NSApplicationPresentationHideMenuBar;
            s_PresentationOptionsOverridden = true;
        }
        else if (!hidden && s_PresentationOptionsOverridden) {
            s_PresentationOptionsOverridden = false;
            NSApp.presentationOptions = s_SavedPresentationOptions;
        }
    }
    @catch (NSException* e) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Unable to change presentation options: %s",
                    e.reason.UTF8String);
    }
}

void MacOSCursor::confineToRegion(SDL_Window* window, const SDL_Rect* region, bool topEdgeOnly)
{
    if (region == nullptr) {
        if (s_EventMonitor != nil) {
            [NSEvent removeMonitor:s_EventMonitor];
            [s_EventMonitor release];
            s_EventMonitor = nil;
        }

        setMenuBarHidden(getNSWindow(s_Window), false);
        s_Window = nullptr;
        return;
    }

    s_Window = window;
    s_Region = *region;
    s_TopEdgeOnly = topEdgeOnly;

    if (s_EventMonitor == nil) {
        s_EventMonitor = [[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved |
                                                                         NSEventMaskLeftMouseDragged |
                                                                         NSEventMaskRightMouseDragged |
                                                                         NSEventMaskOtherMouseDragged
                                                                 handler:^NSEvent*(NSEvent* event) {
            clampCursor();
            return event;
        }] retain];
    }

    setMenuBarHidden(getNSWindow(window), true);

    // Pull the cursor back in right away if it's already outside
    clampCursor();
}
