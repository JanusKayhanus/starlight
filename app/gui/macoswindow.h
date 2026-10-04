#pragma once

class QWindow;

namespace MacOSWindow {

// Extends the window content under a transparent title bar and vertically
// centers the traffic light buttons in a toolbar of the specified height,
// matching the look of a native unified title bar and toolbar.
void useUnifiedTitleBar(QWindow* window, int toolbarHeight = 52);

}
