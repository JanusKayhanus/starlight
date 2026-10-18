import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.impl
import QtQuick.Effects

import SdlGamepadKeyNavigation 1.0

// Pop-up button for the settings panel. Built on the templates so it looks the
// same with every style and system appearance.
T.ComboBox {
    id: control

    property int maximumWidth: 260
    property int textWidth: 0

    implicitWidth: Math.min(maximumWidth, Math.max(90, textWidth + leftPadding + rightPadding))
    implicitHeight: 28
    leftPadding: 10
    rightPadding: 30
    font.pixelSize: 13
    hoverEnabled: true
    activeFocusOnTab: true

    function itemText(index) {
        return textAt(index)
    }

    // Sizes the button to fit the longest option. Callers also invoke this
    // after changing the model's contents.
    function recalculateWidth() {
        metrics.font = font
        var widest = 0
        for (var i = 0; i < count; i++) {
            metrics.text = textAt(i)
            widest = Math.max(widest, metrics.width)
        }
        // Rendered text is slightly wider than measured, so leave some slack
        textWidth = Math.ceil(widest) + 6
    }

    TextMetrics {
        id: metrics
    }

    Component.onCompleted: Qt.callLater(recalculateWidth)
    onCountChanged: Qt.callLater(recalculateWidth)
    onModelChanged: Qt.callLater(recalculateWidth)
    onActivated: recalculateWidth()

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: "white"
        opacity: control.enabled ? 1.0 : 0.4
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    indicator: IconImage {
        x: control.width - width - 9
        y: (control.height - height) / 2
        source: "qrc:/res/sym-chevron-updown.svg"
        sourceSize.width: 13
        sourceSize.height: 13
        color: "white"
        opacity: control.enabled ? 0.6 : 0.25
    }

    background: Rectangle {
        radius: 7
        color: Qt.rgba(1, 1, 1, !control.enabled ? 0.05 :
                                (control.pressed || control.popup.visible ? 0.18 :
                                 (control.hovered ? 0.13 : 0.09)))
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: 10
            color: "transparent"
            border.color: control.palette.highlight
            border.width: 2
            visible: control.visualFocus
        }
    }

    delegate: T.ItemDelegate {
        id: delegate

        required property int index
        required property var model

        width: ListView.view.width
        implicitHeight: 28
        leftPadding: 28
        rightPadding: 12
        highlighted: control.highlightedIndex === index
        hoverEnabled: true

        contentItem: Text {
            text: control.textRole ? delegate.model[control.textRole] : delegate.model.modelData
            font: control.font
            color: "white"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        IconImage {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            source: "qrc:/res/sym-checkmark.svg"
            sourceSize.width: 13
            sourceSize.height: 13
            color: "white"
            visible: control.currentIndex === delegate.index
        }

        background: Rectangle {
            radius: 6
            color: delegate.highlighted ? control.palette.accent : "transparent"
        }
    }

    popup: T.Popup {
        // Right-aligned with the button and kept inside the window
        x: control.width - width
        y: control.height + 4
        width: Math.max(control.width, control.textWidth + 56)
        margins: 8
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 360)
        padding: 5

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
        }

        background: Item {
            Rectangle {
                id: popupBackground
                anchors.fill: parent
                radius: 10
                color: "#2a2a2f"
                border.color: Qt.rgba(1, 1, 1, 0.12)
                visible: false
            }

            MultiEffect {
                source: popupBackground
                anchors.fill: popupBackground
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 0.8
                shadowVerticalOffset: 6
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 110; easing.type: Easing.OutCubic }
        }

        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 }
        }

        // Switch to normal navigation while choosing an option
        onAboutToShow: SdlGamepadKeyNavigation.setUiNavMode(false)
        onAboutToHide: SdlGamepadKeyNavigation.setUiNavMode(true)
    }

    Keys.onLeftPressed: {
        decrementCurrentIndex()
    }

    Keys.onRightPressed: {
        incrementCurrentIndex()
    }
}
