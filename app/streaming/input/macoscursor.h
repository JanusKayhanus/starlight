#pragma once

#include "SDL_compat.h"

namespace MacOSCursor {

// Confines the system cursor to the specified region of the window (in SDL window
// coordinates) by warping it back whenever it strays outside. If topEdgeOnly is set,
// only the top edge is enforced, which keeps the cursor out of the menu bar and notch
// area without preventing it from leaving the window towards other displays.
//
// Pass a null region to stop confining the cursor.
void confineToRegion(SDL_Window* window, const SDL_Rect* region, bool topEdgeOnly);

}
