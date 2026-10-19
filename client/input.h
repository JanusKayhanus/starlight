#pragma once

#include <SDL.h>

// Sends SDL keyboard, mouse, and wheel input to the host. Returns true when
// the user requests that the stream exit.
bool handleInputEvent(const SDL_Event& event);

// Capture the pointer for relative desktop mouse control.
void enableRelativeMouse();
