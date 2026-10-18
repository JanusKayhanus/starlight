import QtQuick
import QtQuick.Templates as T

// Slider for the settings panel. Built on the templates so it looks the
// same with every style and system appearance.
T.Slider {
    id: control

    implicitWidth: 200
    implicitHeight: 22
    padding: 0
    hoverEnabled: true
    activeFocusOnTab: true

    background: Item {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 4

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.16)
        }

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: control.palette.accent
            opacity: control.enabled ? 1.0 : 0.4
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 18
        height: 18
        radius: 9
        color: control.pressed ? "#e6e6e6" : "white"
        border.color: Qt.rgba(0, 0, 0, 0.15)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: width / 2
            color: "transparent"
            border.color: control.palette.highlight
            border.width: 2
            visible: control.visualFocus
        }
    }
}
