#pragma once

#include <functional>

class QWindow;

namespace MacOSWindow {

// Extends the window content under a transparent title bar and vertically
// centers the traffic light buttons in a toolbar of the specified height,
// matching the look of a native unified title bar and toolbar.
void useUnifiedTitleBar(QWindow* window, int toolbarHeight = 52);

// Prepares a stream window (an NSWindow*) to take over from the Qt window:
// styled to match the launcher, optionally given the Qt window's exact frame,
// and kept fully transparent until revealStreamWindow() is called.
void prepareStreamWindow(void* streamWindow, QWindow* qtWindow, bool matchFrame);

// Makes a prepared stream window visible, fading it in over fadeSeconds if
// non-zero, then calls completion.
void revealStreamWindow(void* streamWindow, double fadeSeconds, std::function<void()> completion);

// Moves the Qt window to the stream window's frame, so the UI comes back
// exactly where the stream was.
void adoptStreamWindowFrame(QWindow* qtWindow, void* streamWindow);

}
