#include "macoswindow.h"

#include <QWindow>

#import <Cocoa/Cocoa.h>

// Default horizontal inset of the close button in a unified toolbar
#define TRAFFIC_LIGHT_INSET_X 20

static void layoutTrafficLights(NSWindow* window, int toolbarHeight)
{
    NSButton* close = [window standardWindowButton:NSWindowCloseButton];
    NSButton* miniaturize = [window standardWindowButton:NSWindowMiniaturizeButton];
    NSButton* zoom = [window standardWindowButton:NSWindowZoomButton];
    NSView* container = close.superview.superview;
    if (close == nil || miniaturize == nil || zoom == nil || container == nil ||
            (window.styleMask & NSWindowStyleMaskFullScreen)) {
        return;
    }

    window.titleVisibility = NSWindowTitleHidden;

    // Grow the title bar container to the height of our toolbar, then
    // vertically center the buttons in it
    NSRect containerFrame = container.frame;
    containerFrame.size.height = toolbarHeight;
    containerFrame.origin.y = NSHeight(window.frame) - toolbarHeight;
    container.frame = containerFrame;
    close.superview.frame = container.bounds;

    CGFloat buttonY = round((toolbarHeight - NSHeight(close.frame)) / 2);

    CGFloat spacing = NSMinX(miniaturize.frame) - NSMinX(close.frame);
    NSArray<NSButton*>* buttons = @[close, miniaturize, zoom];
    for (NSUInteger i = 0; i < buttons.count; i++) {
        NSPoint origin = buttons[i].frame.origin;
        origin.x = TRAFFIC_LIGHT_INSET_X + i * spacing;
        origin.y = buttonY;
        [buttons[i] setFrameOrigin:origin];
    }
}

void MacOSWindow::useUnifiedTitleBar(QWindow* window, int toolbarHeight)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
    // Let Qt extend our content under the title bar, so it keeps routing input
    // events in that area to us and preserves the style across window changes.
    window->setFlags(window->flags() | Qt::ExpandedClientAreaHint | Qt::NoTitleBarBackgroundHint);

    NSWindow* nsWindow = reinterpret_cast<NSView*>(window->winId()).window;
    if (nsWindow == nil) {
        return;
    }

    layoutTrafficLights(nsWindow, toolbarHeight);

    // AppKit resets the title bar layout whenever the window changes size or mode
    for (NSNotificationName name in @[NSWindowDidResizeNotification,
                                      NSWindowDidEndLiveResizeNotification,
                                      NSWindowDidExitFullScreenNotification,
                                      NSWindowDidBecomeKeyNotification]) {
        [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                          object:nsWindow
                                                           queue:nil
                                                      usingBlock:^(NSNotification* note) {
            layoutTrafficLights(note.object, toolbarHeight);
        }];
    }
#else
    Q_UNUSED(window);
    Q_UNUSED(toolbarHeight);
#endif
}
