import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

// macOS toolbar button: small monochrome glyph with a rounded hover background
ToolButton {
    id: button
    property string iconSource
    property bool monochrome: true

    activeFocusOnTab: true

    implicitWidth: 34
    implicitHeight: 28
    Layout.alignment: Qt.AlignVCenter

    contentItem: IconImage {
        source: button.iconSource
        sourceSize.width: 18
        sourceSize.height: 18
        fillMode: Image.PreserveAspectFit
        color: button.monochrome ? button.palette.windowText : "transparent"
        opacity: button.enabled ? (button.pressed ? 1.0 : 0.8) : 0.3
    }

    background: Rectangle {
        radius: 6
        color: button.palette.windowText
        opacity: button.pressed ? 0.16 : (button.hovered ? 0.08 : 0)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: 8
            color: "transparent"
            border.color: button.palette.highlight
            border.width: 3
            opacity: button.visualFocus ? 1 : 0
        }
    }

    Keys.onReturnPressed: {
        clicked()
    }

    Keys.onEnterPressed: {
        clicked()
    }

    Keys.onRightPressed: {
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
    }

    Keys.onLeftPressed: {
        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
    }
}
