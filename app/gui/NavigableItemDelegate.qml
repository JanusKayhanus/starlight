import QtQuick
import QtQuick.Templates as T

// macOS grid item: a rounded tile that highlights on hover and shows an
// accent-colored focus ring when selected with the keyboard or a gamepad
T.ItemDelegate {
    id: delegate
    property GridView grid

    highlighted: grid.activeFocus && grid.currentItem === this
    hoverEnabled: true

    background: Rectangle {
        radius: 12
        color: delegate.palette.windowText
        opacity: delegate.down ? 0.12 : (delegate.hovered || delegate.highlighted ? 0.06 : 0)

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    // Keyboard focus ring
    Rectangle {
        z: 1
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.color: delegate.palette.highlight
        border.width: 3
        visible: delegate.highlighted
    }

    Keys.onLeftPressed: {
        grid.moveCurrentIndexLeft()
    }
    Keys.onRightPressed: {
        grid.moveCurrentIndexRight()
    }
    Keys.onDownPressed: {
        grid.moveCurrentIndexDown()
    }
    Keys.onUpPressed: {
        grid.moveCurrentIndexUp()

        // If we've reached the top of the grid, move focus to the toolbar
        if (grid.currentItem === this) {
            nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }
    }
    Keys.onReturnPressed: {
        clicked()
    }
    Keys.onEnterPressed: {
        clicked()
    }
}
