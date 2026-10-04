import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes
import QtCore

import ComputerModel 1.0
import AppModel 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import AutoUpdateChecker 1.0

// macOS launcher, styled after the TV app. Computers are picked from a switcher
// in the title bar, the hero shows the running or selected app (or what the
// selected computer needs, like pairing), and the computer's apps sit below it.
//
// This replaces PcView and AppView when using the native macOS style.
FocusScope {
    id: launcher
    objectName: qsTr("Computers")

    readonly property color backgroundColor: "#141416"
    readonly property int sideMargin: 44
    readonly property int topBarHeight: 52

    // The hero fills the window until there are apps to show below it
    readonly property int heroHeight: hostReady ? Math.round(Math.max(300, Math.min(460, height * 0.52))) : height

    property ComputerModel computerModel: createComputerModel()
    property AppModel appModel: null
    property bool showHiddenGames: false

    // The host switcher segment of the selected computer, which exposes its model roles
    property string selectedUuid: launcherSettings.lastHostUuid
    property Item host: null
    readonly property bool hostReady: host !== null && host.online && host.paired && host.serverSupported

    // Launch the computer's Direct Launch app once its apps are loaded, if the user picked it
    property bool pendingDirectLaunch: false

    // Tiles the hero can feature
    property Item focusedTile: null
    property Item runningTile: null
    property Item firstTile: null
    readonly property Item heroTile: focusedTile ? focusedTile : (runningTile ? runningTile : firstTile)

    // The tile being dragged, which can be dropped in the grid to move it or on the Dock to pin it
    property Item draggedTile: null

    Settings {
        id: launcherSettings
        category: "launcher"
        property string lastHostUuid
    }

    function createComputerModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', launcher, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }

    function selectHost(segment, userInitiated)
    {
        if (segment.uuid !== selectedUuid) {
            showHiddenGames = false
            selectedUuid = segment.uuid
            launcherSettings.lastHostUuid = segment.uuid
        }

        // Like opening a PC in the classic UI, picking a computer launches its Direct Launch app
        pendingDirectLaunch = userInitiated
        if (userInitiated && hostReady) {
            Qt.callLater(rebuildAppModel)
        }
    }

    // Selects a computer when nothing is selected, preferring ones we can stream from
    function ensureSelection()
    {
        if (host !== null || hostRepeater.count === 0) {
            return
        }

        var best = null
        for (var i = 0; i < hostRepeater.count; i++) {
            var segment = hostRepeater.itemAt(i)
            if (segment === null) {
                continue
            }
            var score = (segment.paired ? 2 : 0) + (segment.online ? 1 : 0)
            if (best === null || score > best.score) {
                best = { segment: segment, score: score }
            }
        }

        if (best !== null) {
            selectHost(best.segment, false)
        }
    }

    function rebuildAppModel()
    {
        focusedTile = null
        runningTile = null
        firstTile = null
        appGrid.currentIndex = -1

        if (appModel !== null) {
            appModel.computerLost.disconnect(computerLost)
            appModel.destroy()
            appModel = null
        }

        if (!hostReady) {
            pendingDirectLaunch = false
            return
        }

        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', launcher, '')
        model.initialize(ComputerManager, host.hostIndex, showHiddenGames)
        model.computerLost.connect(computerLost)
        appModel = model

        if (pendingDirectLaunch) {
            pendingDirectLaunch = false
            var directLaunchAppIndex = model.getDirectLaunchAppIndex()
            if (directLaunchAppIndex >= 0) {
                // Delegates for the new model are created synchronously
                appGrid.currentIndex = directLaunchAppIndex
                launchApp(appGrid.currentItem, false)
            }
        }
    }

    function computerLost()
    {
        // The computer went offline or was unpaired, so the hero switches to its status
        Qt.callLater(rebuildAppModel)
    }

    onHostChanged: {
        Qt.callLater(rebuildAppModel)
        Qt.callLater(ensureSelection)
    }
    onHostReadyChanged: Qt.callLater(rebuildAppModel)
    onShowHiddenGamesChanged: Qt.callLater(rebuildAppModel)

    function launchApp(tile, quitExistingApp)
    {
        var runningId = appModel.getRunningAppId()
        if (runningId !== 0 && runningId !== tile.appId) {
            if (quitExistingApp) {
                quitAppDialog.appName = appModel.getRunningAppName()
                quitAppDialog.segueToStream = true
                quitAppDialog.nextAppName = tile.text
                quitAppDialog.nextAppIndex = tile.appIndex
                quitAppDialog.open()
            }

            return
        }

        var component = Qt.createComponent("StreamSegue.qml")
        var segue = component.createObject(stackView, {
                                               "appName": tile.text,
                                               "session": appModel.createSessionForApp(tile.appIndex),
                                               "isResume": runningId === tile.appId
                                           })
        stackView.push(segue)
    }

    function quitRunningApp()
    {
        quitAppDialog.appName = appModel.getRunningAppName()
        quitAppDialog.segueToStream = false
        quitAppDialog.open()
    }

    // Drags a Dock shortcut for the tile's app, so it can be dropped onto the Dock.
    // The grid's DropArea moves the tile around while the drag is over the window.
    function dragToDock(tile)
    {
        // This blocks until the drag ends
        draggedTile = tile
        var error = appModel.dragAppToDock(tile.appIndex)
        draggedTile = null
        if (error) {
            dockErrorDialog.text = error
            dockErrorDialog.open()
        }
    }

    function startPairing()
    {
        var pin = computerModel.generatePinString()

        // Kick off pairing in the background
        computerModel.pairComputer(host.hostIndex, pin)

        // Display the pairing dialog
        pairDialog.pin = pin
        pairDialog.open()
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    // Shows the menu under anchorItem, or at the mouse cursor if there's none
    function popupMenu(menu, anchorItem)
    {
        if (anchorItem) {
            menu.popup(anchorItem, 0, anchorItem.height + 4)
        }
        else {
            menu.popup()
        }
    }

    function openHostMenu(segment, anchorItem)
    {
        if (segment !== host) {
            selectHost(segment, false)
        }

        popupMenu(hostMenu, anchorItem)
    }

    function streamSettingsText()
    {
        var parts = [StreamingPreferences.width + "×" + StreamingPreferences.height,
                     qsTr("%1 FPS").arg(StreamingPreferences.fps)]
        if (StreamingPreferences.enableHdr) {
            parts.push(qsTr("HDR"))
        }
        return parts.join(" · ")
    }

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        ComputerManager.computerAddCompleted.connect(addComplete)

        // Highlight the first app if a gamepad is connected
        if (appGrid.count > 0 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            appGrid.headerItem.focusApps()
        }
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    Rectangle {
        anchors.fill: parent
        color: launcher.backgroundColor
    }

    GridView {
        id: appGrid

        readonly property real availableWidth: width - 2 * (launcher.sideMargin - 8)
        readonly property int columns: Math.max(2, Math.floor(availableWidth / 184))

        anchors.fill: parent
        focus: true
        activeFocusOnTab: true
        leftMargin: launcher.sideMargin - 8
        rightMargin: launcher.sideMargin - 8
        bottomMargin: 32
        cellWidth: Math.floor(availableWidth / columns)
        cellHeight: Math.round((cellWidth - 16) * 3 / 2) + 72
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        model: launcher.appModel

        // Not interactive while the hero fills the window
        interactive: launcher.hostReady

        header: FocusScope {
            id: headerRoot
            width: appGrid.width
            height: launcher.hostReady ? launcher.heroHeight + 58 : launcher.height

            function focusFirstAction() {
                for (var i = 0; i < heroActions.children.length; i++) {
                    var button = heroActions.children[i]
                    if (button.visible && button.activeFocusOnTab) {
                        button.forceActiveFocus(Qt.TabFocusReason)
                        return
                    }
                }
                focusApps()
            }

            function focusApps() {
                if (appGrid.count > 0) {
                    appGrid.currentIndex = launcher.heroTile ? launcher.heroTile.appIndex : 0
                    appGrid.forceActiveFocus(Qt.TabFocusReason)
                }
            }

            Item {
                // GridView positions the header at the left margin, but the hero spans the window
                x: -appGrid.leftMargin
                width: appGrid.width
                height: parent.height

                Item {
                    id: hero

                    readonly property Item tile: launcher.hostReady ? launcher.heroTile : null
                    readonly property bool hasArt: tile !== null && !tile.artwork.isPlaceholder
                    readonly property var host: launcher.host
                    readonly property string mode: host === null ? "none" :
                                                   host.statusUnknown ? "connecting" :
                                                   !host.online ? "offline" :
                                                   !host.paired ? "unpaired" :
                                                   !host.serverSupported ? "unsupported" :
                                                   tile === null ? "noapps" : "app"

                    // Glow colors for the backdrop when there's no box art to blur
                    readonly property var glowColors: tile !== null ? [tile.artwork.placeholderColors[1], tile.artwork.placeholderColors[0]] :
                                                      mode === "offline" || mode === "connecting" ? ["#4a4d57", "#24262d"] :
                                                      ["#00a2ed", "#0063b1"]

                    width: parent.width
                    height: launcher.heroHeight
                    clip: true

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: -1
                            fillGradient: RadialGradient {
                                centerX: hero.width * 0.72
                                centerY: hero.height * 0.12
                                centerRadius: Math.max(hero.width, hero.height) * 0.62
                                focalX: centerX
                                focalY: centerY
                                GradientStop { position: 0.0; color: hero.glowColors[0] }
                                GradientStop { position: 0.4; color: hero.glowColors[1] }
                                GradientStop { position: 1.0; color: launcher.backgroundColor }
                            }

                            startX: 0; startY: 0
                            PathLine { x: hero.width; y: 0 }
                            PathLine { x: hero.width; y: hero.height }
                            PathLine { x: 0; y: hero.height }
                            PathLine { x: 0; y: 0 }
                        }
                    }

                    // Blurred box art of the featured app
                    Image {
                        anchors.fill: parent
                        anchors.margins: -80
                        source: hero.hasArt ? hero.tile.artwork.source : ""
                        visible: hero.hasArt && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320

                        layer.enabled: visible
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 64
                            saturation: 0.3
                            brightness: -0.08
                        }
                    }

                    // Fade into the window background, and darken behind the text and title bar
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.3) }
                            GradientStop { position: 0.2; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.alpha(launcher.backgroundColor, 0.2) }
                            GradientStop { position: 1.0; color: launcher.backgroundColor }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.alpha(launcher.backgroundColor, 0.7) }
                            GradientStop { position: 0.6; color: "transparent" }
                        }
                    }

                    Column {
                        id: heroContent
                        x: launcher.sideMargin
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: launcher.hostReady ? 30 : Math.round(parent.height * 0.3)
                        width: Math.min(660, hero.width - 2 * launcher.sideMargin)
                        spacing: 0

                        Row {
                            spacing: 7
                            height: 18

                            BusyIndicator {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                visible: hero.mode === "connecting" || (hero.mode === "none" && StreamingPreferences.enableMdns)
                                running: visible
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                visible: hero.mode !== "none" && hero.mode !== "connecting"
                                color: hero.mode === "app" ? (hero.tile.running ? "#0a84ff" : "#32d74b") :
                                       hero.host !== null ? hero.host.statusColor : "transparent"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                font.capitalization: Font.AllUppercase
                                text: {
                                    switch (hero.mode) {
                                    case "none": return StreamingPreferences.enableMdns ? qsTr("Searching your network") : qsTr("No computers")
                                    case "connecting": return qsTr("Connecting")
                                    case "offline": return qsTr("Offline")
                                    case "unpaired": return qsTr("Not paired")
                                    case "unsupported": return qsTr("Update required")
                                    case "noapps": return qsTr("Online")
                                    default: return hero.tile.running ? qsTr("Running on %1").arg(hero.host.text)
                                                                      : qsTr("On %1").arg(hero.host.text)
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            topPadding: 6
                            bottomPadding: 4
                            color: "white"
                            font.pixelSize: 46
                            font.weight: Font.ExtraBold
                            font.letterSpacing: -0.8
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 0.95
                            text: hero.mode === "none" ? qsTr("Add a Computer") :
                                  hero.mode === "app" ? hero.tile.text : hero.host.text
                        }

                        Text {
                            width: parent.width
                            bottomPadding: 18
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                            lineHeight: 1.15
                            text: {
                                switch (hero.mode) {
                                case "none":
                                    return StreamingPreferences.enableMdns ?
                                                qsTr("Looking for computers running Sunshine or GeForce Experience. You can also add one by its IP address.") :
                                                qsTr("Automatic discovery is turned off. Add your computer by its IP address.")
                                case "connecting": return qsTr("Checking whether %1 is available…").arg(hero.host.text)
                                case "offline":
                                    return hero.host.wakeable ? qsTr("%1 isn't responding. Wake it to start streaming.").arg(hero.host.text)
                                                              : qsTr("%1 isn't responding. Make sure it's turned on and connected to the network.").arg(hero.host.text)
                                case "unpaired": return qsTr("Pair this Mac with %1 to see its apps and start streaming.").arg(hero.host.text)
                                case "unsupported": return qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(hero.host.text)
                                case "noapps": return qsTr("This computer doesn't have any apps, or they're all hidden.")
                                default: return hero.tile.running ? qsTr("Pick up where you left off · %1").arg(launcher.streamSettingsText())
                                                                  : qsTr("Streams at %1").arg(launcher.streamSettingsText())
                                }
                            }
                        }

                        Row {
                            id: heroActions
                            spacing: 10

                            LauncherButton {
                                primary: true
                                visible: hero.mode === "app"
                                iconSource: "qrc:/res/sym-play.svg"
                                text: hero.tile !== null && hero.tile.running ? qsTr("Resume") : qsTr("Play")
                                onClicked: launcher.launchApp(hero.tile, true)
                            }
                            LauncherButton {
                                visible: hero.mode === "app" && hero.tile.running
                                iconSource: "qrc:/res/sym-stop.svg"
                                text: qsTr("Quit App")
                                onClicked: launcher.quitRunningApp()
                            }

                            LauncherButton {
                                primary: true
                                visible: hero.mode === "none"
                                iconSource: "qrc:/res/sym-plus.svg"
                                text: qsTr("Add Computer…")
                                onClicked: addPcDialog.open()
                            }
                            LauncherButton {
                                visible: hero.mode === "none" && SystemProperties.hasBrowser
                                text: qsTr("Setup Guide")
                                onClicked: Qt.openUrlExternally("https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide")
                            }

                            LauncherButton {
                                primary: true
                                visible: hero.mode === "offline" && hero.host.wakeable
                                iconSource: "qrc:/res/sym-power.svg"
                                text: qsTr("Wake")
                                onClicked: computerModel.wakeComputer(hero.host.hostIndex)
                            }
                            LauncherButton {
                                visible: hero.mode === "offline"
                                text: qsTr("Test Network")
                                onClicked: {
                                    computerModel.testConnectionForComputer(hero.host.hostIndex)
                                    testConnectionDialog.open()
                                }
                            }

                            LauncherButton {
                                primary: true
                                visible: hero.mode === "unpaired"
                                text: qsTr("Pair…")
                                onClicked: launcher.startPairing()
                            }

                            LauncherButton {
                                visible: hero.mode === "unsupported" && SystemProperties.hasBrowser
                                text: qsTr("Get Latest Moonlight")
                                onClicked: Qt.openUrlExternally("https://github.com/moonlight-stream/moonlight-qt/releases")
                            }

                            LauncherButton {
                                visible: hero.mode === "noapps" && !launcher.showHiddenGames
                                text: qsTr("Show Hidden Apps")
                                onClicked: launcher.showHiddenGames = true
                            }
                        }
                    }

                    // Arrow keys move between the hero, the title bar and the apps
                    Keys.onDownPressed: headerRoot.focusApps()
                    Keys.onUpPressed: {
                        if (launcher.host !== null) {
                            launcher.host.forceActiveFocus(Qt.TabFocusReason)
                        }
                    }
                }

                // Shelf title
                Row {
                    visible: launcher.hostReady
                    x: launcher.sideMargin
                    anchors.top: hero.bottom
                    anchors.topMargin: 14
                    spacing: 10

                    Text {
                        id: shelfTitle
                        text: launcher.showHiddenGames ? qsTr("All Apps") : qsTr("Apps")
                        color: "white"
                        font.pixelSize: 19
                        font.weight: Font.Bold
                    }

                    Text {
                        y: shelfTitle.baselineOffset - baselineOffset
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        text: appGrid.count === 0 ? qsTr("This computer doesn't have any apps, or they're all hidden")
                                                  : (appGrid.count === 1 ? qsTr("1 on this computer")
                                                                         : qsTr("%1 on this computer").arg(appGrid.count))
                    }
                }
            }
        }

        delegate: LauncherTile {
            readonly property int appIndex: index
            readonly property int appId: model.appid
            readonly property bool running: model.running
            readonly property bool hidden: model.hidden
            readonly property bool directLaunch: model.directLaunch

            width: appGrid.cellWidth
            height: appGrid.cellHeight
            leftPadding: 8
            rightPadding: 8
            grid: appGrid
            text: model.name
            artwork.source: model.boxart
            artwork.isAppCollectorGame: model.appCollectorGame
            opacity: launcher.draggedTile === this ? 0.3 : (hidden ? 0.45 : 1.0)
            subtitle: running ? qsTr("Running") :
                      hidden ? qsTr("Hidden") :
                      directLaunch ? qsTr("Direct Launch") : ""

            function updateTileRefs() {
                if (running) {
                    launcher.runningTile = this
                }
                else if (launcher.runningTile === this) {
                    launcher.runningTile = null
                }

                if (index === 0) {
                    launcher.firstTile = this
                }
                else if (launcher.firstTile === this) {
                    launcher.firstTile = null
                }
            }

            Component.onCompleted: updateTileRefs()
            onRunningChanged: updateTileRefs()
            onAppIndexChanged: updateTileRefs()
            Component.onDestruction: {
                if (launcher.runningTile === this) {
                    launcher.runningTile = null
                }
                if (launcher.firstTile === this) {
                    launcher.firstTile = null
                }
                if (launcher.focusedTile === this) {
                    launcher.focusedTile = null
                }
            }

            selected: launcher.heroTile === this

            // A click selects the app for the hero; Play/Resume there launches it
            onClicked: {
                appGrid.currentIndex = index
                launcher.focusedTile = this
            }
            onDoubleClicked: launcher.launchApp(this, true)
            onDragStarted: launcher.dragToDock(this)
            onActivated: launcher.launchApp(this, true)
            onNavigated: launcher.focusedTile = appGrid.currentItem

            onPressAndHold: {
                appMenu.tile = this
                appMenu.popup()
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: parent.pressAndHold()
            }

            Keys.onMenuPressed: {
                // This will be keyboard/gamepad driven, so show it under the tile
                appMenu.tile = this
                launcher.popupMenu(appMenu, this)
            }
        }

        // Keep keyboard navigation starting from the app shown in the hero.
        // GridView also moves its current item on its own (like to the first
        // app when the model loads), so the hero only follows user selections.
        Connections {
            target: launcher
            function onHeroTileChanged() {
                if (launcher.heroTile) {
                    appGrid.currentIndex = launcher.heroTile.appIndex
                }
            }
        }

        // Animate tiles into their new places while one is dragged around
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
        }

        ScrollBar.vertical: OverlayScrollBar {
            // Keep the scroll bar out of the title bar
            topPadding: launcher.topBarHeight
            darkBackground: true
        }
    }

    // Rearranges tiles while one is dragged over the grid. Dropping outside the window
    // (like on the Dock) is handled by the drag itself.
    DropArea {
        id: reorderArea
        anchors.fill: appGrid
        anchors.topMargin: launcher.topBarHeight
        keys: ["application/x-moonlight-app"]
        enabled: launcher.draggedTile !== null

        // Scrolls the grid while the drag is near its top or bottom edge
        property real scrollSpeed: 0

        function moveDraggedTile() {
            var tile = launcher.draggedTile
            if (tile === null || appGrid.count === 0) {
                return
            }

            // Work out the cell from the layout rather than the tiles, which may be mid-animation
            var point = mapToItem(appGrid.contentItem, drag.x, drag.y)
            var column = Math.floor(point.x / appGrid.cellWidth)
            var row = Math.floor(point.y / appGrid.cellHeight)
            if (row < 0 || column < 0 || column >= appGrid.columns) {
                return
            }

            var index = Math.min(row * appGrid.columns + column, appGrid.count - 1)
            if (index !== tile.appIndex) {
                appModel.moveApp(tile.appIndex, index)
                appGrid.currentIndex = tile.appIndex
            }
        }

        onPositionChanged: {
            var edge = 60
            scrollSpeed = drag.y < edge ? -(edge - drag.y) / 3 :
                          drag.y > height - edge ? (drag.y - height + edge) / 3 : 0
            moveDraggedTile()
        }
        onExited: scrollSpeed = 0
        onDropped: (drop) => {
            scrollSpeed = 0
            drop.acceptProposedAction()
        }

        Timer {
            interval: 16
            repeat: true
            running: reorderArea.containsDrag && reorderArea.scrollSpeed !== 0
            onTriggered: {
                var minY = appGrid.originY - appGrid.topMargin
                var maxY = Math.max(minY, appGrid.originY + appGrid.contentHeight + appGrid.bottomMargin - appGrid.height)
                appGrid.contentY = Math.max(minY, Math.min(maxY, appGrid.contentY + reorderArea.scrollSpeed))
                reorderArea.moveDraggedTile()
            }
        }
    }

    // Title bar: traffic lights on the left, the computer switcher in the middle
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        height: launcher.topBarHeight

        // Fade in a bar background once the apps scroll under the title bar
        readonly property bool scrolledUnder: appGrid.headerItem !== null &&
                                               appGrid.contentY - appGrid.originY > appGrid.headerItem.height - 58 - height

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.08, 0.08, 0.09, 0.92)
            opacity: topBar.scrolledUnder ? 1 : 0

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // Drag the window from the title bar
        MouseArea {
            anchors.fill: parent
            onPressed: launcher.Window.window.startSystemMove()
            onDoubleClicked: {
                var window = launcher.Window.window
                if (window.visibility === Window.Maximized) {
                    window.showNormal()
                }
                else {
                    window.showMaximized()
                }
            }
        }

        // Computer switcher
        Rectangle {
            id: hostSwitcher
            anchors.centerIn: parent
            width: Math.min(hostFlick.contentWidth, topBar.width - 2 * 120) + addHostButton.width + 6
            height: 30
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.32)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1

            Flickable {
                id: hostFlick
                x: 3
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(contentWidth, topBar.width - 2 * 120)
                height: 24
                contentWidth: hostRow.width
                contentHeight: height
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: hostRow
                    height: parent.height

                    Repeater {
                        id: hostRepeater
                        model: launcher.computerModel

                        onItemAdded: Qt.callLater(launcher.ensureSelection)
                        onItemRemoved: Qt.callLater(launcher.ensureSelection)

                        delegate: AbstractButton {
                            id: segment

                            readonly property int hostIndex: index
                            readonly property string uuid: model.uuid
                            readonly property bool online: model.online
                            readonly property bool paired: model.paired
                            readonly property bool busy: model.busy
                            readonly property bool wakeable: model.wakeable
                            readonly property bool statusUnknown: model.statusUnknown
                            readonly property bool serverSupported: model.serverSupported
                            readonly property string details: model.details
                            readonly property bool isSelected: uuid === launcher.selectedUuid

                            readonly property string statusText: statusUnknown ? qsTr("Connecting…") :
                                                                 !online ? qsTr("Offline") :
                                                                 !paired ? qsTr("Not Paired") :
                                                                 busy ? qsTr("App Running") : qsTr("Online")
                            readonly property color statusColor: statusUnknown || !online ? Qt.rgba(1, 1, 1, 0.3) :
                                                                 !paired ? "#ff9f0a" :
                                                                 busy ? "#0a84ff" : "#32d74b"

                            function updateSelection() {
                                if (isSelected) {
                                    launcher.host = this
                                }
                                else if (launcher.host === this) {
                                    launcher.host = null
                                }
                            }

                            Component.onCompleted: updateSelection()
                            onIsSelectedChanged: updateSelection()
                            Component.onDestruction: {
                                if (launcher.host === this) {
                                    launcher.host = null
                                }
                            }

                            height: parent.height
                            leftPadding: 12
                            rightPadding: 13
                            activeFocusOnTab: true
                            hoverEnabled: true
                            text: model.name

                            contentItem: Row {
                                spacing: 7

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 7
                                    height: 7
                                    radius: 3.5
                                    color: segment.statusColor
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: segment.text
                                    color: segment.isSelected || segment.hovered ? "white" : Qt.rgba(1, 1, 1, 0.7)
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }

                            background: Rectangle {
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, segment.isSelected ? 0.2 : (segment.hovered ? 0.08 : 0))
                                border.color: segment.palette.highlight
                                border.width: segment.visualFocus ? 2 : 0
                            }

                            ToolTip.text: segment.statusText
                            ToolTip.delay: 800
                            ToolTip.timeout: 3000
                            ToolTip.visible: hovered

                            onClicked: launcher.selectHost(segment, true)
                            onPressAndHold: launcher.openHostMenu(segment, null)

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: launcher.openHostMenu(segment, null)
                            }

                            Keys.onReturnPressed: clicked()
                            Keys.onEnterPressed: clicked()
                            Keys.onMenuPressed: launcher.openHostMenu(segment, segment)
                            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocusReason)
                            Keys.onDownPressed: appGrid.headerItem.focusFirstAction()
                        }
                    }
                }
            }

            LauncherIconButton {
                id: addHostButton
                anchors.left: hostFlick.right
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 24
                iconSource: "qrc:/res/sym-plus.svg"
                // ⌘N comes from the File menu
                toolTip: qsTr("Add Computer… (%1)").arg("⌘N")
                onClicked: addPcDialog.open()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            BusyIndicator {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                visible: StreamingPreferences.enableMdns && hostRepeater.count === 0
                running: visible
            }

            LauncherIconButton {
                property string browserUrl

                id: updateButton
                visible: false
                iconSource: "qrc:/res/update.svg"
                monochrome: false

                function updateAvailable(version, url) {
                    toolTip = qsTr("Update available for Moonlight: Version %1").arg(version)
                    browserUrl = url
                    visible = true
                }

                Component.onCompleted: AutoUpdateChecker.onUpdateAvailable.connect(updateAvailable)
                onClicked: Qt.openUrlExternally(browserUrl)
            }

            LauncherIconButton {
                id: hostOptionsButton
                iconSource: "qrc:/res/sym-ellipsis.svg"
                toolTip: qsTr("Computer Options")
                enabled: launcher.host !== null
                onClicked: launcher.openHostMenu(launcher.host, hostOptionsButton)
            }

            LauncherIconButton {
                iconSource: "qrc:/res/sym-gear.svg"
                toolTip: qsTr("Settings")
                onClicked: settingsButton.clicked()
            }
        }
    }

    // Context menu for the selected computer
    NavigableMenu {
        id: hostMenu
        initiator: launcher.host !== null ? launcher.host : launcher

        MenuItem {
            text: launcher.host !== null ? qsTr("%1 — %2").arg(launcher.host.text).arg(launcher.host.statusText) : ""
            font.bold: true
            enabled: false
        }
        NavigableMenuItem {
            text: qsTr("Pair…")
            available: launcher.host !== null && launcher.host.online && !launcher.host.paired
            onTriggered: launcher.startPairing()
        }
        NavigableMenuItem {
            text: qsTr("Wake PC")
            available: launcher.host !== null && !launcher.host.online && launcher.host.wakeable
            onTriggered: computerModel.wakeComputer(launcher.host.hostIndex)
        }
        NavigableMenuItem {
            checkable: true
            checked: launcher.showHiddenGames
            text: qsTr("Show Hidden Apps")
            available: launcher.hostReady
            onTriggered: launcher.showHiddenGames = !launcher.showHiddenGames
        }
        NavigableMenuItem {
            text: qsTr("Test Network")
            onTriggered: {
                computerModel.testConnectionForComputer(launcher.host.hostIndex)
                testConnectionDialog.open()
            }
        }
        NavigableMenuItem {
            text: qsTr("Rename…")
            onTriggered: {
                renamePcDialog.pcIndex = launcher.host.hostIndex
                renamePcDialog.originalName = launcher.host.text
                renamePcDialog.open()
            }
        }
        NavigableMenuItem {
            text: qsTr("View Details")
            onTriggered: {
                showPcDetailsDialog.pcDetails = launcher.host.details
                showPcDetailsDialog.open()
            }
        }
        NavigableMenuItem {
            text: qsTr("Remove…")
            onTriggered: {
                deletePcDialog.pcIndex = launcher.host.hostIndex
                deletePcDialog.pcName = launcher.host.text
                deletePcDialog.open()
            }
        }
    }

    // Context menu for an app tile
    NavigableMenu {
        id: appMenu
        property Item tile: null
        initiator: tile !== null ? tile : launcher

        NavigableMenuItem {
            text: appMenu.tile !== null && appMenu.tile.running ? qsTr("Resume Game") : qsTr("Launch Game")
            onTriggered: launcher.launchApp(appMenu.tile, true)
        }
        NavigableMenuItem {
            text: qsTr("Quit Game")
            available: appMenu.tile !== null && appMenu.tile.running
            onTriggered: launcher.quitRunningApp()
        }
        NavigableMenuItem {
            checkable: true
            checked: appMenu.tile !== null && appMenu.tile.directLaunch
            text: qsTr("Direct Launch")
            enabled: appMenu.tile !== null && !appMenu.tile.hidden
            onTriggered: appModel.setAppDirectLaunch(appMenu.tile.appIndex, !appMenu.tile.directLaunch)
        }
        NavigableMenuItem {
            checkable: true
            checked: appMenu.tile !== null && appMenu.tile.hidden
            text: qsTr("Hide Game")
            enabled: appMenu.tile !== null && (appMenu.tile.hidden || (!appMenu.tile.running && !appMenu.tile.directLaunch))
            onTriggered: appModel.setAppHidden(appMenu.tile.appIndex, !appMenu.tile.hidden)
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: dockErrorDialog
        imageSrc: "qrc:/res/baseline-error_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

    NavigableMessageDialog {
        id: pairDialog
        closePolicy: Popup.CloseOnEscape

        // don't allow edits to the rest of the window while open
        property string pin : "0000"
        text:qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pin)+"\n\n"+
             qsTr("If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN.")
        standardButtons: Dialog.Cancel
        onRejected: {
            // FIXME: We should interrupt pairing here
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        text:qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                // Store the session and app name if we're going to stream after
                // successfully quitting the old app.
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }
}
