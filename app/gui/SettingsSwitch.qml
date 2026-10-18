import QtQuick
import QtQuick.Templates as T

// Toggle switch for the settings panel. Built on the templates so it looks the
// same with every style and system appearance.
T.Switch {
    id: control

    implicitWidth: 38
    implicitHeight: 22
    padding: 0
    hoverEnabled: true
    activeFocusOnTab: true

    indicator: Rectangle {
        width: control.width
        height: control.height
        radius: height / 2
        color: control.checked ? control.palette.accent
                               : Qt.rgba(1, 1, 1, control.hovered ? 0.24 : 0.18)
        opacity: control.enabled ? 1.0 : 0.4

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
            y: 2
            width: parent.height - 4
            height: width
            radius: width / 2
            color: "white"

            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.color: control.palette.highlight
            border.width: 2
            visible: control.visualFocus
        }
    }

    contentItem: Item {}

    Keys.onReturnPressed: {
        toggle()
        toggled()
    }

    Keys.onEnterPressed: {
        toggle()
        toggled()
    }
}
