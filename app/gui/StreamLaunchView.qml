import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import StreamingPreferences 1.0

// Launch transition for the macOS launcher. The window lifts into a card and
// the launcher fades into a blurred snapshot of where the last session left
// off while a capsule shows connection progress. Once connected, the card
// sharpens and drops back down to fill the window, handing off to the stream.
Item {
    id: view

    // Image of the launcher at the moment of launch (an ItemGrabResult), if any
    property var launcherGrab: null

    property string snapshotUrl
    property date snapshotTime
    readonly property bool hasSnapshot: snapshotUrl !== ""

    property string title
    property string stageText
    property string hint

    // Stage callbacks seen so far, out of the typical number of connection stages
    property int stagesStarted: 0
    readonly property int expectedStages: 10

    signal outroFinished()

    // Animated state
    property real cardScale: 1
    property real cardLift: 0
    property real cardRadius: 0
    property real shadowStrength: 0
    property real snapOpacity: 0
    property real snapBlur: hasSnapshot ? 0.35 : 0.8
    property real snapDim: 1
    property real tagOpacity: 0
    property string capsuleState: "closed"

    readonly property var easeOut: [0.2, 0.9, 0.1, 1, 1, 1]

    function stageStarted(stage) {
        stageText = qsTr("Starting %1…").arg(stage)
        stagesStarted++
    }

    function playIntro() {
        introAnimation.start()
    }

    function playOutro() {
        introAnimation.stop()
        outroAnimation.start()
    }

    ParallelAnimation {
        id: introAnimation

        NumberAnimation { target: view; property: "cardScale"; to: 0.86; duration: 750; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "cardLift"; to: -18; duration: 750; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "cardRadius"; to: 14; duration: 750; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "shadowStrength"; to: 1; duration: 750 }
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: view; property: "snapOpacity"; to: 1; duration: 450; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 850 }
            NumberAnimation { target: view; property: "tagOpacity"; to: 1; duration: 400 }
        }
        ScriptAction { script: view.capsuleState = "open" }
    }

    ParallelAnimation {
        id: outroAnimation

        ScriptAction { script: view.capsuleState = "done" }
        NumberAnimation { target: view; property: "tagOpacity"; to: 0; duration: 300 }
        NumberAnimation { target: view; property: "snapBlur"; to: 0; duration: 800; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "snapDim"; to: 0; duration: 800; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "snapOpacity"; to: 1; duration: 200 }
        NumberAnimation { target: view; property: "cardScale"; to: 1; duration: 800; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "cardLift"; to: 0; duration: 800; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "cardRadius"; to: 0; duration: 800; easing.type: Easing.BezierSpline; easing.bezierCurve: view.easeOut }
        NumberAnimation { target: view; property: "shadowStrength"; to: 0; duration: 800 }

        onFinished: view.outroFinished()
    }

    // Backdrop revealed around the card
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1d1e2a" }
            GradientStop { position: 1.0; color: "#0b0b0d" }
        }
    }

    // The card: the launcher fading into the snapshot, with rounded corners and a shadow
    Item {
        id: stage
        anchors.fill: parent

        transform: [
            Scale {
                origin.x: stage.width / 2
                origin.y: stage.height / 2
                xScale: view.cardScale
                yScale: view.cardScale
            },
            Translate { y: view.cardLift }
        ]

        RectangularShadow {
            anchors.fill: parent
            radius: view.cardRadius
            offset.y: 24
            blur: 60
            color: Qt.rgba(0, 0, 0, 0.6 * view.shadowStrength)
            visible: view.shadowStrength > 0
        }

        Item {
            id: cardContent
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                color: "#121214"
            }

            Image {
                anchors.fill: parent
                source: view.launcherGrab ? view.launcherGrab.url : ""
                fillMode: Image.PreserveAspectCrop
            }

            // Where the last session left off, or the launcher itself heavily
            // frosted if there's no snapshot yet
            Image {
                id: snapshotImage
                anchors.fill: parent
                source: view.hasSnapshot ? view.snapshotUrl : (view.launcherGrab ? view.launcherGrab.url : "")
                fillMode: Image.PreserveAspectCrop
                cache: false
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: snapshotImage
                opacity: view.snapOpacity
                blurEnabled: true
                blurMax: 48
                blur: view.snapBlur
                brightness: -0.14 * view.snapDim
                saturation: -0.1 * view.snapDim
            }

            // Tag explaining what's shown
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 64
                width: tagRow.implicitWidth + 28
                height: 30
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.45)
                border.color: Qt.rgba(1, 1, 1, 0.14)
                opacity: view.tagOpacity
                visible: view.hasSnapshot

                Row {
                    id: tagRow
                    anchors.centerIn: parent
                    spacing: 8

                    Shape {
                        width: 14
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.8)
                            strokeWidth: 1.4
                            fillColor: "transparent"
                            PathAngleArc { centerX: 7; centerY: 7; radiusX: 5.6; radiusY: 5.6; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.8)
                            strokeWidth: 1.4
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 7; startY: 4
                            PathLine { x: 7; y: 7.2 }
                            PathLine { x: 9; y: 8.5 }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Snapshot from your last session · %1").arg(view.snapshotTime.toLocaleString(Qt.locale(), Locale.ShortFormat))
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font.pixelSize: 12
                    }
                }
            }
        }

        Item {
            id: cardMask
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: view.cardRadius
                color: "black"
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: cardContent
            maskEnabled: true
            maskSource: cardMask
        }
    }

    // Disconnect hint in the space below the card
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: view.hint
        color: Qt.rgba(1, 1, 1, 0.4)
        font.pixelSize: 12
        opacity: view.shadowStrength
    }

    RectangularShadow {
        anchors.fill: capsule
        radius: capsule.radius
        offset.y: 14
        blur: 40
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: capsule.opacity
    }

    // Progress capsule
    Rectangle {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        color: "black"
        border.color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        width: view.capsuleState === "open" ? 400 : (view.capsuleState === "done" ? 320 : 120)
        height: view.capsuleState === "open" ? 68 : (view.capsuleState === "done" ? 38 : 30)
        radius: height / 2
        opacity: view.capsuleState === "closed" ? 0 : 1

        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on opacity { NumberAnimation { duration: 300 } }

        // Connecting: spinner, title and stage, progress ring
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            opacity: view.capsuleState === "open" ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 250 } }

            // Four panes lighting up clockwise in turn
            Grid {
                id: spinner
                columns: 2
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                property int step: 0
                readonly property var order: [0, 1, 3, 2]

                Timer {
                    interval: 220
                    repeat: true
                    running: view.capsuleState === "open"
                    onTriggered: spinner.step++
                }

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        readonly property bool lit: index === spinner.order[spinner.step % 4] ||
                                                    index === spinner.order[(spinner.step + 3) % 4]
                        width: 13.5
                        height: 13.5
                        radius: 2.5
                        color: lit ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.18)

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            Column {
                width: parent.width - spinner.width - ring.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: view.title
                    color: "white"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: view.stageText
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Shape {
                id: ring
                width: 30
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                preferredRendererType: Shape.CurveRenderer

                property real progress: Math.min(1, view.stagesStarted / view.expectedStages)
                Behavior on progress { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.15)
                    strokeWidth: 3
                    fillColor: "transparent"
                    PathAngleArc { centerX: 15; centerY: 15; radiusX: 12; radiusY: 12; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: "#0a84ff"
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 15; centerY: 15; radiusX: 12; radiusY: 12; startAngle: -90; sweepAngle: 360 * ring.progress }
                }
            }
        }

        // Connected
        Row {
            anchors.centerIn: parent
            spacing: 8
            opacity: view.capsuleState === "done" ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 250 } }

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: "#32d74b"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: qsTr("Connected · %1×%2 · %3 FPS").arg(StreamingPreferences.width).arg(StreamingPreferences.height).arg(StreamingPreferences.fps)
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
    }
}
