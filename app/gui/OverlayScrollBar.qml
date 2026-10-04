import QtQuick
import QtQuick.Controls.Basic as Basic

// macOS-style overlay scroller: hidden at rest, shown while scrolling or when the
// pointer is over it, then fades out. The native macOS style draws its scroll bar
// permanently and can't be customized, so this is built on the Basic style.
Basic.ScrollBar {
    id: control

    // Light thumb on dark backgrounds, dark thumb otherwise. Follows the system
    // appearance by default; the always-dark launcher sets it explicitly.
    property bool darkBackground: palette.window.hslLightness < 0.5

    // Stays true briefly after the last scroll so the thumb doesn't flicker
    property bool recentlyScrolled: false

    readonly property bool shown: (recentlyScrolled || active || hovered || pressed) && size < 1.0

    policy: Basic.ScrollBar.AsNeeded
    padding: 2
    rightPadding: 3
    implicitWidth: hovered || pressed ? 15 : 11
    minimumSize: 0.08

    onPositionChanged: {
        recentlyScrolled = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 800
        onTriggered: control.recentlyScrolled = false
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: 120 }
    }

    background: Rectangle {
        // Faint track appears only when hovering, like macOS
        radius: width / 2
        color: control.darkBackground ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)
        opacity: control.shown && (control.hovered || control.pressed) ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: width / 2
        color: control.darkBackground
               ? Qt.rgba(1, 1, 1, control.pressed ? 0.7 : 0.5)
               : Qt.rgba(0, 0, 0, control.pressed ? 0.6 : 0.45)
        opacity: control.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: control.shown ? 100 : 500; easing.type: Easing.OutQuad }
        }
    }
}
