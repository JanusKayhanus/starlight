import QtQuick
import QtQuick.Controls

// Item for the native NSMenu-backed NavigableMenu. Items in a native menu
// are never visible in the scene, so enabled must not depend on visible,
// and NavigableMenu adds or removes items based on available instead.
MenuItem {
    property bool available: true
}
