import QtQuick

// A titled card of SettingsRows in the settings panel
Column {
    id: section

    property string title
    default property alias rows: rowsColumn.data

    width: parent ? parent.width : 0
    spacing: 8

    function updateSeparators() {
        var first = true
        for (var i = 0; i < rowsColumn.children.length; i++) {
            var child = rowsColumn.children[i]
            if (child.showSeparator === undefined || !child.visible) {
                continue
            }
            child.showSeparator = !first
            first = false
        }
    }

    Text {
        text: section.title.toUpperCase()
        color: Qt.rgba(1, 1, 1, 0.45)
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        leftPadding: 14
    }

    Rectangle {
        width: parent.width
        height: rowsColumn.height
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.045)
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Column {
            id: rowsColumn
            width: parent.width
            onPositioningComplete: section.updateSeparators()
        }
    }
}
