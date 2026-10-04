import QtQuick
import QtQuick.Effects

// Box art with rounded corners and a hairline border, like artwork in macOS apps
Image {
    id: image

    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
    }

    Item {
        id: mask
        width: image.width
        height: image.height
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: 10
        }
    }
}
