import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl

// Large pill button for the launcher hero, like the Play buttons in the TV app.
// Primary buttons are solid white, the rest are translucent glass.
AbstractButton {
    id: button
    property string iconSource
    property bool primary: false

    implicitHeight: 36
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    leftPadding: iconSource ? 18 : 22
    rightPadding: 22
    activeFocusOnTab: true
    hoverEnabled: true

    font.pixelSize: 14
    font.weight: Font.DemiBold

    contentItem: Row {
        spacing: 7

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.iconSource
            source: button.iconSource
            sourceSize.width: 15
            sourceSize.height: 15
            color: label.color
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            font: button.font
            color: button.primary ? "black" : "white"
        }
    }

    background: Rectangle {
        radius: height / 2
        color: button.primary ? Qt.rgba(1, 1, 1, button.down ? 0.75 : (button.hovered ? 0.92 : 1))
                              : Qt.rgba(1, 1, 1, button.down ? 0.28 : (button.hovered ? 0.22 : 0.15))

        // Keyboard focus ring
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: height / 2
            color: "transparent"
            border.color: button.palette.highlight
            border.width: 3
            visible: button.visualFocus
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
    Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
}
