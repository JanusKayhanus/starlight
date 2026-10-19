#pragma once

struct SDL_Window;

// Diagnostic helper for the macOS stream window: logs the underlying
// NSWindow's frame, style, level, and collection behavior.
void LogStreamWindowInfo(SDL_Window* window, const char* when);

// Configures the stream window for edge-to-edge presentation. On current
// macOS releases the menu bar reserves space even for fullscreen windows, so
// hide it (and the Dock) for the duration of the stream. When the window is a
// borderless fullscreen window rather than a fullscreen Space, also promote it
// to a normal managed window so it appears in Mission Control and can be moved
// between displays.
void MacOSConfigureStreamWindow(SDL_Window* window, bool useSpaces);

// Restores the menu bar and Dock after the stream ends.
void MacOSRestoreAfterStreaming();
