import QtQuick
import QtQuick.Controls

// Uses a real NSMenu for context menus
Menu {
    property var initiator

    // Every item declared in the menu, in order, including ones
    // currently taken out because they aren't available
    property var allItems: []

    popupType: Popup.Native

    // Native menus ignore Item.visible, so add or remove
    // items to match their available property instead
    function syncAvailableItems() {
        var pos = 0
        for (var i = 0; i < allItems.length; i++) {
            var item = allItems[i]
            var wanted = item.available === undefined || item.available
            var present = itemAt(pos) === item
            if (wanted) {
                if (!present) {
                    insertItem(pos, item)
                }
                pos++
            }
            else if (present) {
                takeItem(pos)
            }
        }
    }

    Component.onCompleted: {
        var items = []
        for (var i = 0; i < count; i++) {
            var item = itemAt(i)
            items.push(item)
            if (item.availableChanged) {
                item.availableChanged.connect(syncAvailableItems)
            }
        }
        allItems = items
        syncAvailableItems()
    }

    onOpened: {
        // If the initiating object currently has keyboard focus,
        // give focus to the first enabled menu item
        if (initiator.focus) {
            for (var i = 0; i < count; i++) {
                var item = itemAt(i)
                if (item.enabled) {
                    item.forceActiveFocus(Qt.TabFocusReason)
                    break
                }
            }
        }
    }
}
