#include "macoswindow.h"

#include <QWindow>

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

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

static NSWindow* nsWindowForQtWindow(QWindow* window)
{
    return reinterpret_cast<NSView*>(window->winId()).window;
}

void MacOSWindow::prepareStreamWindow(void* streamWindow, QWindow* qtWindow, bool matchFrame)
{
    NSWindow* window = (__bridge NSWindow*)streamWindow;
    if (window == nil) {
        return;
    }

    // Dark, borderless-looking title bar to match the launcher
    window.titlebarAppearsTransparent = YES;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.backgroundColor = NSColor.blackColor;

    if (matchFrame && qtWindow != nullptr) {
        NSWindow* launcherWindow = nsWindowForQtWindow(qtWindow);
        if (launcherWindow != nil) {
            [window setFrame:launcherWindow.frame display:NO];
        }
    }

    // Stay on screen (so rendering starts normally) but invisible until revealed
    window.alphaValue = 0.0;
}

void MacOSWindow::revealStreamWindow(void* streamWindow, double fadeSeconds, std::function<void()> completion)
{
    NSWindow* window = (__bridge NSWindow*)streamWindow;
    if (window == nil || fadeSeconds <= 0) {
        window.alphaValue = 1.0;
        completion();
        return;
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
        context.duration = fadeSeconds;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        window.animator.alphaValue = 1.0;
    } completionHandler:^{
        completion();
    }];
}

void MacOSWindow::adoptStreamWindowFrame(QWindow* qtWindow, void* streamWindow)
{
    NSWindow* window = (__bridge NSWindow*)streamWindow;
    NSWindow* launcherWindow = qtWindow != nullptr ? nsWindowForQtWindow(qtWindow) : nil;
    if (window == nil || launcherWindow == nil) {
        return;
    }

    [launcherWindow setFrame:window.frame display:NO];
}
