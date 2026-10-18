import QtQuick
import QtQuick.Layouts

// A row in a SettingsSection: a title and optional description on the left,
// with a control on the right and optional full-width content underneath.
Item {
    id: row

    property string title
    property string subtitle

    // Clicking anywhere on the row toggles this switch
    property Item toggleTarget: null

    // Managed by SettingsSection so only rows after the first get a separator
    property bool showSeparator: true

    default property alias control: controlSlot.data
    property alias below: belowSlot.data

    // Wide controls like pop-up buttons would squeeze the description into a
    // narrow column, so it moves below the title and control instead
    readonly property bool wideControl: controlSlot.implicitWidth > width * 0.3

    width: parent ? parent.width : 0
    implicitHeight: Math.max(46, layout.implicitHeight + 22)

    Rectangle {
        x: 14
        width: parent.width - 14
        height: 1
        color: Qt.rgba(1, 1, 1, 0.07)
        visible: row.showSeparator
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.toggleTarget !== null && row.toggleTarget.enabled
        onClicked: {
            row.toggleTarget.toggle()
            row.toggleTarget.toggled()
        }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        RowLayout {
            spacing: 16
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 3
                Layout.fillWidth: true

                Text {
                    text: row.title
                    color: "white"
                    opacity: row.enabled ? 1.0 : 0.4
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Text {
                    text: row.subtitle
                    visible: text.length > 0 && !row.wideControl
                    color: Qt.rgba(1, 1, 1, row.enabled ? 0.5 : 0.25)
                    font.pixelSize: 12
                    lineHeight: 1.1
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            Item {
                id: controlSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
        }

        Text {
            text: row.subtitle
            visible: text.length > 0 && row.wideControl
            color: Qt.rgba(1, 1, 1, row.enabled ? 0.5 : 0.25)
            font.pixelSize: 12
            lineHeight: 1.1
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.topMargin: -6
        }

        Item {
            id: belowSlot
            implicitHeight: childrenRect.height
            visible: children.length > 0
            Layout.fillWidth: true
        }
    }
}
