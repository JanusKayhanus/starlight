import QtQuick

// Starts a native drag once the mouse moves past the drag threshold, so items can be
// dragged out of the window (e.g. onto the Dock). The drag runs in a nested event loop,
// so the handler is reset afterwards in case the release went to the drag session.
DragHandler {
    id: handler
    signal dragStarted()

    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    acceptedButtons: Qt.LeftButton
    grabPermissions: PointerHandler.CanTakeOverFromAnything

    onActiveChanged: {
        if (active) {
            Qt.callLater(function() {
                handler.dragStarted()
                handler.enabled = false
                handler.enabled = true
            })
        }
    }
}
