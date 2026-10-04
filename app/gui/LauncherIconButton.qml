import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl

// Small round glyph button for the launcher title bar
AbstractButton {
    id: button
    property string iconSource
    property bool monochrome: true
    property string toolTip

    implicitWidth: 30
    implicitHeight: 30
    activeFocusOnTab: true
    hoverEnabled: true

    contentItem: IconImage {
        source: button.iconSource
        sourceSize.width: 17
        sourceSize.height: 17
        fillMode: Image.PreserveAspectFit
        color: button.monochrome ? "white" : "transparent"
        opacity: button.enabled ? (button.hovered || button.pressed ? 1.0 : 0.75) : 0.3
    }

    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(1, 1, 1, button.pressed ? 0.2 : (button.hovered ? 0.1 : 0))
        border.color: button.palette.highlight
        border.width: button.visualFocus ? 2 : 0
    }

    ToolTip.text: toolTip
    ToolTip.delay: 800
    ToolTip.timeout: 3000
    ToolTip.visible: hovered && toolTip

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
    Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
}
