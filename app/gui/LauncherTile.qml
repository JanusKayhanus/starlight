import QtQuick
import QtQuick.Templates as T
import QtQuick.Effects

// Portrait app tile in the launcher grid, sized for box art. It lifts on hover
// and gets a white ring while it's the app shown in the hero, like the TV app.
T.ItemDelegate {
    id: tile
    property GridView grid
    property alias artwork: artwork
    property string subtitle
    property bool selected: false

    // Emitted by Return/Enter (and a gamepad's A button) to launch the app
    signal activated()
    // Emitted after the arrow keys move the grid's current item
    signal navigated()
    // Emitted when the user starts dragging the tile, to rearrange it or drop it on the Dock
    signal dragStarted()

    readonly property bool lifted: hovered || highlighted

    // The hero lives in the grid's header, so the grid keeps active focus while it's focused
    highlighted: grid.activeFocus && grid.currentItem === this &&
                 !(grid.headerItem && grid.headerItem.activeFocus)
    hoverEnabled: true
    padding: 0

    contentItem: Item {
        LauncherArtwork {
            id: artwork
            width: parent.width
            height: Math.round(width * 3 / 2)
            title: tile.text
            scale: tile.down ? 0.98 : (tile.lifted ? 1.035 : 1.0)

            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        // Soft shadow under the artwork
        RectangularShadow {
            anchors.fill: artwork
            z: -1
            scale: artwork.scale
            radius: artwork.radius
            offset.y: tile.lifted ? 14 : 8
            blur: tile.lifted ? 34 : 20
            color: Qt.rgba(0, 0, 0, tile.lifted ? 0.6 : 0.4)
        }

        // Selection ring
        Rectangle {
            anchors.fill: artwork
            anchors.margins: -4
            scale: artwork.scale
            radius: artwork.radius + 4
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.9)
            border.width: 3
            visible: tile.selected
        }

        Text {
            id: nameText
            anchors.top: artwork.bottom
            anchors.topMargin: 10
            width: parent.width
            text: tile.text
            color: Qt.rgba(1, 1, 1, 0.92)
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            anchors.top: nameText.bottom
            anchors.topMargin: 2
            width: parent.width
            text: tile.subtitle
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    DockDragHandler {
        onDragStarted: tile.dragStarted()
    }

    Keys.onLeftPressed: {
        grid.moveCurrentIndexLeft()
        navigated()
    }
    Keys.onRightPressed: {
        grid.moveCurrentIndexRight()
        navigated()
    }
    Keys.onDownPressed: {
        grid.moveCurrentIndexDown()
        navigated()
    }
    Keys.onUpPressed: {
        grid.moveCurrentIndexUp()

        // If we've reached the top of the grid, move focus to the hero
        if (grid.currentItem === this) {
            grid.headerItem.focusFirstAction()
        }
        else {
            navigated()
        }
    }
    Keys.onReturnPressed: {
        activated()
    }
    Keys.onEnterPressed: {
        activated()
    }
}
