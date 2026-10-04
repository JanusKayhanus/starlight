import QtQuick
import QtQuick.Effects

// Box art for a portrait launcher tile. Posters that are narrower than the
// tile are shown in front of a blurred, enlarged copy of themselves.
// Apps without real box art get a colored gradient with their name.
Item {
    id: artwork
    property url source
    property string title
    property bool isAppCollectorGame: false
    property real radius: 12

    // Whether the host only gave us a generic placeholder image
    readonly property bool isPlaceholder: poster.status !== Image.Ready ||
        (!isAppCollectorGame &&
         ((poster.implicitWidth === 130 && poster.implicitHeight === 180) || // GFE 2.0 placeholder image
          (poster.implicitWidth === 628 && poster.implicitHeight === 888) || // GFE 3.0 placeholder image
          (poster.implicitWidth === 200 && poster.implicitHeight === 266)))  // Our no_app_image.png

    // Placeholder colors, picked from the app name so they stay the same between launches
    readonly property var placeholderGradients: [
        ["#1b2838", "#3d6a8a"], ["#3d1f5c", "#a24bd1"], ["#0b2a4a", "#c2453c"],
        ["#123b2e", "#3fa37c"], ["#3a2410", "#d08a3a"], ["#1d2340", "#5a6fd6"]
    ]
    readonly property var placeholderColors: {
        var hash = 0
        for (var i = 0; i < title.length; i++) {
            hash = (hash * 31 + title.charCodeAt(i)) % 9973
        }
        return placeholderGradients[hash % placeholderGradients.length]
    }

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
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: artwork.placeholderColors[0] }
            GradientStop { position: 1.0; color: artwork.placeholderColors[1] }
        }
    }

    // Soft color wash behind the poster
    Image {
        anchors.fill: parent
        anchors.margins: -parent.height / 2
        visible: !artwork.isPlaceholder && artwork.inset
        source: artwork.source
        sourceSize.width: 60
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true

        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.05
        }
    }

    // When the poster is narrower than the tile, it sits on the wash as an
    // inset card, like album art on the blurred background in Music
    readonly property bool inset: poster.implicitHeight > 0 &&
                                  poster.implicitWidth / poster.implicitHeight < artwork.width / artwork.height - 0.05
    readonly property real posterInset: inset ? Math.round(height * 0.08) : 0

    RectangularShadow {
        anchors.fill: poster
        visible: artwork.inset && poster.visible
        radius: posterMask.radius
        offset.y: 4
        blur: 16
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Image {
        id: poster
        anchors.centerIn: parent
        height: parent.height - 2 * artwork.posterInset
        width: implicitHeight > 0 ? Math.min(parent.width, height * implicitWidth / implicitHeight) : 0
        visible: !artwork.isPlaceholder
        source: artwork.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true

        layer.enabled: artwork.inset
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: posterMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        id: posterMask
        width: poster.width
        height: poster.height
        radius: Math.max(4, artwork.radius - 4)
        visible: false
        layer.enabled: true
    }

    Text {
        anchors.fill: parent
        anchors.margins: 16
        visible: artwork.isPlaceholder
        text: artwork.title
        color: "white"
        font.pixelSize: Math.max(15, artwork.height / 6)
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.25)
    }

    // Hairline edge, like artwork in macOS apps
    Rectangle {
        anchors.fill: parent
        radius: artwork.radius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
    }

    Item {
        id: mask
        width: artwork.width
        height: artwork.height
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: artwork.radius
        }
    }
}
