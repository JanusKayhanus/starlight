import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQuick.Window

import StreamingPreferences 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import SystemProperties 1.0

// Settings, shown in a panel that slides in over the right side of the window.
// The contents are created each time the panel opens, so lists like the
// detected display resolutions are always current.
T.Drawer {
    id: settingsDrawer

    edge: Qt.RightEdge
    width: Math.min(500, (parent ? parent.width : 500) - 40)
    height: parent ? parent.height : 0
    modal: true
    dim: true
    focus: true
    padding: 0

    // Only open from the Settings button, never by dragging from the window edge
    dragMargin: 0

    function toggle() {
        if (visible) {
            close()
        }
        else {
            open()
        }
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.4)
    }

    enter: Transition {
        NumberAnimation { property: "position"; to: 1.0; duration: 260; easing.type: Easing.OutCubic }
    }

    exit: Transition {
        NumberAnimation { property: "position"; to: 0.0; duration: 200; easing.type: Easing.InCubic }
    }

    background: Rectangle {
        color: "#1a1a1d"

        // Shadow cast onto the content beside the panel
        Rectangle {
            x: -24
            width: 24
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: Qt.rgba(1, 1, 1, 0.1)
        }
    }

    onAboutToShow: {
        // This enables Tab and BackTab based navigation rather than arrow keys.
        // It is required to shift focus between controls in the settings panel.
        SdlGamepadKeyNavigation.setUiNavMode(true)
    }

    onOpened: {
        // Highlight the first item if a gamepad is connected
        if (SdlGamepadKeyNavigation.getConnectedGamepads() > 0 && contentLoader.item) {
            contentLoader.item.focusFirstControl()
        }
    }

    onClosed: {
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Save the prefs so the Session can observe the changes
        StreamingPreferences.save()

        // Return focus to the page underneath
        if (stackView.currentItem) {
            stackView.currentItem.forceActiveFocus()
        }
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        active: settingsDrawer.visible
        focus: true
        sourceComponent: settingsContent
    }

    Component {
        id: settingsContent

        FocusScope {
            id: settingsPage

            signal languageChanged()

            readonly property var sections: [videoSection, audioSection, inputSection, gamepadSection,
                                             hostSection, networkSection, generalSection, advancedSection]

            // The section scrolled to the top of the panel, which is highlighted in the section bar
            readonly property int currentSectionIndex: {
                if (flick.contentHeight > flick.height && flick.contentY >= flick.contentHeight - flick.height - 2) {
                    return sections.length - 1
                }

                var index = 0
                for (var i = 0; i < sections.length; i++) {
                    if (sections[i].y <= flick.contentY + 24) {
                        index = i
                    }
                }
                return index
            }

            function focusFirstControl() {
                resolutionComboBox.forceActiveFocus(Qt.TabFocusReason)
            }

            function scrollToSection(index) {
                var target = Math.max(0, Math.min(sections[index].y - 4, flick.contentHeight - flick.height))
                autoScrollAnimation.stop()
                autoScrollAnimation.from = flick.contentY
                autoScrollAnimation.to = target
                autoScrollAnimation.duration = 250
                autoScrollAnimation.start()
            }

            Component.onDestruction: {
                // Also save preferences on destruction, since we won't get a
                // closed callback if the user just quits Moonlight
                StreamingPreferences.save()
            }

            Keys.onMenuPressed: settingsDrawer.close()

            // This is a keypress we've reserved for letting the
            // SdlGamepadKeyNavigation object tell us to show settings
            // when Menu is consumed by a focused control.
            Keys.onHangupPressed: settingsDrawer.close()

            // Keep the focused control in view while navigating with a keyboard or gamepad
            Window.onActiveFocusItemChanged: {
                var item = Window.activeFocusItem
                if (!item || !isInScrollArea(item)) {
                    return
                }

                // Map the focus item's position into our content item's coordinate space
                var pos = item.mapToItem(flick.contentItem, 0, 0)

                // Ensure some extra space is visible around the element we're scrolling to
                var scrollMargin = flick.height > 100 ? 50 : 0

                autoScrollAnimation.duration = 100
                if (pos.y - scrollMargin < flick.contentY) {
                    autoScrollAnimation.from = flick.contentY
                    autoScrollAnimation.to = Math.max(pos.y - scrollMargin, 0)
                    autoScrollAnimation.start()
                }
                else if (pos.y + item.height + scrollMargin > flick.contentY + flick.height) {
                    autoScrollAnimation.from = flick.contentY
                    autoScrollAnimation.to = Math.min(pos.y + item.height + scrollMargin - flick.height,
                                                      flick.contentHeight - flick.height)
                    autoScrollAnimation.start()
                }
            }

            function isInScrollArea(item) {
                while (item) {
                    if (item === flick.contentItem) {
                        return true
                    }
                    item = item.parent
                }
                return false
            }

            // Title bar
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52

                // The panel covers part of the title bar, so let it move the window too
                MouseArea {
                    anchors.fill: parent
                    onPressed: window.startSystemMove()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Settings")
                    color: "white"
                    font.pixelSize: 17
                    font.weight: Font.Bold
                }

                LauncherIconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    iconSource: "qrc:/res/sym-xmark.svg"
                    toolTip: qsTr("Close")
                    activeFocusOnTab: false
                    onClicked: settingsDrawer.close()
                }
            }

            // Section bar
            Flickable {
                id: sectionBar
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34
                contentWidth: sectionRow.width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: sectionRow
                    spacing: 0
                    leftPadding: 10
                    rightPadding: 10

                    Repeater {
                        model: settingsPage.sections

                        T.AbstractButton {
                            id: sectionButton

                            required property int index
                            required property var modelData

                            readonly property bool current: settingsPage.currentSectionIndex === index

                            text: modelData.title
                            implicitWidth: sectionLabel.implicitWidth + 16
                            implicitHeight: 26
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus

                            contentItem: Text {
                                id: sectionLabel
                                text: sectionButton.text
                                color: sectionButton.current || sectionButton.hovered ? "white" : Qt.rgba(1, 1, 1, 0.6)
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, sectionButton.current ? 0.14 : (sectionButton.hovered ? 0.07 : 0))
                            }

                            onClicked: settingsPage.scrollToSection(index)
                        }
                    }
                }
            }

            Rectangle {
                id: headerSeparator
                anchors.top: sectionBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }

            Flickable {
                id: flick
                anchors.top: headerSeparator.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentHeight: contentColumn.height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.vertical: OverlayScrollBar {
                    darkBackground: true
                }

                NumberAnimation on contentY {
                    id: autoScrollAnimation
                    duration: 100
                    easing.type: Easing.OutCubic
                }

                Column {
                    id: contentColumn
                    x: 16
                    width: flick.width - 32
                    topPadding: 18
                    bottomPadding: 24
                    spacing: 24

                    SettingsSection {
                        id: videoSection
                        title: qsTr("Video")

                        SettingsRow {
                            title: qsTr("Resolution")
                            subtitle: qsTr("Setting values too high for your PC or network connection may cause lag, stuttering, or errors.")

                            SettingsComboBox {
                                property int lastIndexValue

                                function addDetectedResolution(friendlyNamePrefix, rect) {
                                    var indexToAdd = 0
                                    for (var j = 0; j < resolutionComboBox.count; j++) {
                                        var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                        var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                        if (rect.width === existing_width && rect.height === existing_height) {
                                            // Duplicate entry, skip
                                            indexToAdd = -1
                                            break
                                        }
                                        else if (rect.width * rect.height > existing_width * existing_height) {
                                            // Candidate entrypoint after this entry
                                            indexToAdd = j + 1
                                        }
                                    }

                                    // Insert this display's resolution if it's not a duplicate
                                    if (indexToAdd >= 0) {
                                        resolutionListModel.insert(indexToAdd,
                                                                   {
                                                                       "text": friendlyNamePrefix+" ("+rect.width+"x"+rect.height+")",
                                                                       "video_width": ""+rect.width,
                                                                       "video_height": ""+rect.height,
                                                                       "is_custom": false
                                                                   })
                                    }
                                }

                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    // Refresh display data before using it to build the list
                                    SystemProperties.refreshDisplays()

                                    // Add native and safe area resolutions for all attached displays
                                    var done = false
                                    for (var displayIndex = 0; !done; displayIndex++) {
                                        var screenRect = SystemProperties.getNativeResolution(displayIndex);
                                        var safeAreaRect = SystemProperties.getSafeAreaResolution(displayIndex);

                                        if (screenRect.width === 0) {
                                            // Exceeded max count of displays
                                            done = true
                                            break
                                        }

                                        addDetectedResolution(qsTr("Native"), screenRect)
                                        addDetectedResolution(qsTr("Native (Excluding Notch)"), safeAreaRect)
                                    }

                                    // Prune resolutions that are over the decoder's maximum
                                    var max_pixels = SystemProperties.maximumResolution.width * SystemProperties.maximumResolution.height;
                                    if (max_pixels > 0) {
                                        for (var j = 0; j < resolutionComboBox.count; j++) {
                                            var existing_width = parseInt(resolutionListModel.get(j).video_width);
                                            var existing_height = parseInt(resolutionListModel.get(j).video_height);

                                            if (existing_width * existing_height > max_pixels) {
                                                resolutionListModel.remove(j)
                                                j--
                                            }
                                        }
                                    }

                                    // load the saved width/height, and iterate through the ComboBox until a match is found
                                    // and set it to that index.
                                    var saved_width = StreamingPreferences.width
                                    var saved_height = StreamingPreferences.height
                                    var index_set = false
                                    for (var i = 0; i < resolutionListModel.count; i++) {
                                        var el_width = parseInt(resolutionListModel.get(i).video_width);
                                        var el_height = parseInt(resolutionListModel.get(i).video_height);

                                        if (saved_width === el_width && saved_height === el_height) {
                                            currentIndex = i
                                            index_set = true
                                            break
                                        }
                                    }

                                    if (!index_set) {
                                        // We did not find a match. This must be a custom resolution.
                                        resolutionListModel.append({
                                                                       "text": qsTr("Custom")+" ("+StreamingPreferences.width+"x"+StreamingPreferences.height+")",
                                                                       "video_width": ""+StreamingPreferences.width,
                                                                       "video_height": ""+StreamingPreferences.height,
                                                                       "is_custom": true
                                                                   })
                                        currentIndex = resolutionListModel.count - 1
                                    }
                                    else {
                                        resolutionListModel.append({
                                                                       "text": qsTr("Custom"),
                                                                       "video_width": "",
                                                                       "video_height": "",
                                                                       "is_custom": true
                                                                   })
                                    }

                                    // Since we don't call activate() here, we need to trigger
                                    // width calculation manually
                                    recalculateWidth()

                                    lastIndexValue = currentIndex
                                }

                                id: resolutionComboBox
                                maximumWidth: 300
                                textRole: "text"
                                model: ListModel {
                                    id: resolutionListModel
                                    // Other elements may be added at runtime
                                    // based on attached display resolution
                                    ListElement {
                                        text: qsTr("720p")
                                        video_width: "1280"
                                        video_height: "720"
                                        is_custom: false
                                    }
                                    ListElement {
                                        text: qsTr("1080p")
                                        video_width: "1920"
                                        video_height: "1080"
                                        is_custom: false
                                    }
                                    ListElement {
                                        text: qsTr("1440p")
                                        video_width: "2560"
                                        video_height: "1440"
                                        is_custom: false
                                    }
                                    ListElement {
                                        text: qsTr("4K")
                                        video_width: "3840"
                                        video_height: "2160"
                                        is_custom: false
                                    }
                                }

                                function updateBitrateForSelection() {
                                    var selectedWidth = parseInt(resolutionListModel.get(currentIndex).video_width)
                                    var selectedHeight = parseInt(resolutionListModel.get(currentIndex).video_height)

                                    // Only modify the bitrate if the values actually changed
                                    if (StreamingPreferences.width !== selectedWidth || StreamingPreferences.height !== selectedHeight) {
                                        StreamingPreferences.width = selectedWidth
                                        StreamingPreferences.height = selectedHeight

                                        if (StreamingPreferences.autoAdjustBitrate) {
                                            StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                                      StreamingPreferences.height,
                                                                                                                      StreamingPreferences.fps,
                                                                                                                      StreamingPreferences.enableYUV444);
                                            slider.value = StreamingPreferences.bitrateKbps
                                        }
                                    }

                                    lastIndexValue = currentIndex
                                }

                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    if (resolutionListModel.get(currentIndex).is_custom) {
                                        customResolutionDialog.open()
                                    }
                                    else {
                                        updateBitrateForSelection()
                                    }
                                }

                                NavigableDialog {
                                    id: customResolutionDialog
                                    standardButtons: Dialog.Ok | Dialog.Cancel
                                    onOpened: {
                                        // Force keyboard focus on the textbox so keyboard navigation works
                                        widthField.forceActiveFocus()

                                        // standardButton() was added in Qt 5.10, so we must check for it first
                                        if (customResolutionDialog.standardButton) {
                                            customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                        }
                                    }

                                    onClosed: {
                                        widthField.clear()
                                        heightField.clear()
                                    }

                                    onRejected: {
                                        resolutionComboBox.currentIndex = resolutionComboBox.lastIndexValue
                                    }

                                    function isInputValid() {
                                        // If we have text in either textbox that isn't valid,
                                        // reject the input.
                                        if ((!widthField.acceptableInput && widthField.text) ||
                                                (!heightField.acceptableInput && heightField.text)) {
                                            return false
                                        }

                                        // The textboxes need to have text or placeholder text
                                        if ((!widthField.text && !widthField.placeholderText) ||
                                                (!heightField.text && !heightField.placeholderText)) {
                                            return false
                                        }

                                        return true
                                    }

                                    onAccepted: {
                                        // Reject if there's invalid input
                                        if (!isInputValid()) {
                                            reject()
                                            return
                                        }

                                        var width = widthField.text ? widthField.text : widthField.placeholderText
                                        var height = heightField.text ? heightField.text : heightField.placeholderText

                                        // Find and update the custom entry
                                        for (var i = 0; i < resolutionListModel.count; i++) {
                                            if (resolutionListModel.get(i).is_custom) {
                                                resolutionListModel.setProperty(i, "video_width", width)
                                                resolutionListModel.setProperty(i, "video_height", height)
                                                resolutionListModel.setProperty(i, "text", "Custom ("+width+"x"+height+")")

                                                // Now update the bitrate using the custom resolution
                                                resolutionComboBox.currentIndex = i
                                                resolutionComboBox.updateBitrateForSelection()

                                                // Update the combobox width too
                                                resolutionComboBox.recalculateWidth()
                                                break
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Label {
                                            text: qsTr("Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.") + "\n\n" +
                                                  qsTr("Resolutions that are not supported by your client or host PC may cause streaming errors.") + "\n"
                                            wrapMode: Label.WordWrap
                                            Layout.maximumWidth: 300
                                        }

                                        Label {
                                            text: qsTr("Enter a custom resolution:")
                                            font.bold: true
                                        }

                                        RowLayout {
                                            TextField {
                                                id: widthField
                                                maximumLength: 5
                                                inputMethodHints: Qt.ImhDigitsOnly
                                                placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_width
                                                validator: IntValidator{bottom:256; top:8192}
                                                focus: true

                                                onTextChanged: {
                                                    // standardButton() was added in Qt 5.10, so we must check for it first
                                                    if (customResolutionDialog.standardButton) {
                                                        customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                                    }
                                                }

                                                Keys.onReturnPressed: {
                                                    customResolutionDialog.accept()
                                                }

                                                Keys.onEnterPressed: {
                                                    customResolutionDialog.accept()
                                                }
                                            }

                                            Label {
                                                text: "x"
                                                font.bold: true
                                            }

                                            TextField {
                                                id: heightField
                                                maximumLength: 5
                                                inputMethodHints: Qt.ImhDigitsOnly
                                                placeholderText: resolutionListModel.get(resolutionComboBox.currentIndex).video_height
                                                validator: IntValidator{bottom:256; top:8192}

                                                onTextChanged: {
                                                    // standardButton() was added in Qt 5.10, so we must check for it first
                                                    if (customResolutionDialog.standardButton) {
                                                        customResolutionDialog.standardButton(Dialog.Ok).enabled = customResolutionDialog.isInputValid()
                                                    }
                                                }

                                                Keys.onReturnPressed: {
                                                    customResolutionDialog.accept()
                                                }

                                                Keys.onEnterPressed: {
                                                    customResolutionDialog.accept()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Frame rate")

                            SettingsComboBox {
                                property int lastIndexValue

                                function updateBitrateForSelection() {
                                    // Only modify the bitrate if the values actually changed
                                    var selectedFps = parseInt(model.get(fpsComboBox.currentIndex).video_fps)
                                    if (StreamingPreferences.fps !== selectedFps) {
                                        StreamingPreferences.fps = selectedFps

                                        if (StreamingPreferences.autoAdjustBitrate) {
                                            StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                                      StreamingPreferences.height,
                                                                                                                      StreamingPreferences.fps,
                                                                                                                      StreamingPreferences.enableYUV444);
                                            slider.value = StreamingPreferences.bitrateKbps
                                        }
                                    }

                                    lastIndexValue = currentIndex
                                }

                                NavigableDialog {
                                    function isInputValid() {
                                        // If we have text that isn't valid, reject the input.
                                        if (!fpsField.acceptableInput && fpsField.text) {
                                            return false
                                        }

                                        // The textbox needs to have text or placeholder text
                                        if (!fpsField.text && !fpsField.placeholderText) {
                                            return false
                                        }

                                        return true
                                    }

                                    id: customFpsDialog
                                    standardButtons: Dialog.Ok | Dialog.Cancel
                                    onOpened: {
                                        // Force keyboard focus on the textbox so keyboard navigation works
                                        fpsField.forceActiveFocus()

                                        // standardButton() was added in Qt 5.10, so we must check for it first
                                        if (customFpsDialog.standardButton) {
                                            customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                        }
                                    }

                                    onClosed: {
                                        fpsField.clear()
                                    }

                                    onRejected: {
                                        fpsComboBox.currentIndex = fpsComboBox.lastIndexValue
                                    }

                                    onAccepted: {
                                        // Reject if there's invalid input
                                        if (!isInputValid()) {
                                            reject()
                                            return
                                        }

                                        var fps = fpsField.text ? fpsField.text : fpsField.placeholderText

                                        // Find and update the custom entry
                                        for (var i = 0; i < fpsListModel.count; i++) {
                                            if (fpsListModel.get(i).is_custom) {
                                                fpsListModel.setProperty(i, "video_fps", fps)
                                                fpsListModel.setProperty(i, "text", qsTr("Custom (%1 FPS)").arg(fps))

                                                // Now update the bitrate using the custom resolution
                                                fpsComboBox.currentIndex = i
                                                fpsComboBox.updateBitrateForSelection()

                                                // Update the combobox width too
                                                fpsComboBox.recalculateWidth()
                                                break
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Label {
                                            text: qsTr("Enter a custom frame rate:")
                                            font.bold: true
                                        }

                                        RowLayout {
                                            TextField {
                                                id: fpsField
                                                maximumLength: 4
                                                inputMethodHints: Qt.ImhDigitsOnly
                                                placeholderText: fpsListModel.get(fpsComboBox.currentIndex).video_fps
                                                validator: IntValidator{bottom:10; top:9999}
                                                focus: true

                                                onTextChanged: {
                                                    // standardButton() was added in Qt 5.10, so we must check for it first
                                                    if (customFpsDialog.standardButton) {
                                                        customFpsDialog.standardButton(Dialog.Ok).enabled = customFpsDialog.isInputValid()
                                                    }
                                                }

                                                Keys.onReturnPressed: {
                                                    customFpsDialog.accept()
                                                }

                                                Keys.onEnterPressed: {
                                                    customFpsDialog.accept()
                                                }
                                            }
                                        }
                                    }
                                }

                                function addRefreshRateOrdered(fpsListModel, refreshRate, description, custom) {
                                    var indexToAdd = 0
                                    for (var j = 0; j < fpsListModel.count; j++) {
                                        var existing_fps = parseInt(fpsListModel.get(j).video_fps);

                                        if (refreshRate === existing_fps || (custom && fpsListModel.get(j).is_custom)) {
                                            // Duplicate entry, skip
                                            indexToAdd = -1
                                            break
                                        }
                                        else if (refreshRate > existing_fps) {
                                            // Candidate entrypoint after this entry
                                            indexToAdd = j + 1
                                        }
                                    }

                                    // Insert this frame rate if it's not a duplicate
                                    if (indexToAdd >= 0) {
                                        // Custom values always go at the end of the list
                                        if (custom) {
                                            indexToAdd = fpsListModel.count
                                        }

                                        fpsListModel.insert(indexToAdd,
                                                            {
                                                                "text": description,
                                                                "video_fps": ""+refreshRate,
                                                                "is_custom": custom
                                                            })
                                    }

                                    return indexToAdd
                                }

                                function reinitialize() {
                                    // Add native refresh rate for all attached displays
                                    var done = false
                                    for (var displayIndex = 0; !done; displayIndex++) {
                                        var refreshRate = SystemProperties.getRefreshRate(displayIndex);
                                        if (refreshRate === 0) {
                                            // Exceeded max count of displays
                                            done = true
                                            break
                                        }

                                        addRefreshRateOrdered(fpsListModel, refreshRate, qsTr("%1 FPS").arg(refreshRate), false)
                                    }

                                    var saved_fps = StreamingPreferences.fps
                                    var found = false
                                    for (var i = 0; i < model.count; i++) {
                                        var el_fps = parseInt(model.get(i).video_fps);

                                        // Look for a matching frame rate
                                        if (saved_fps === el_fps) {
                                            currentIndex = i
                                            found = true
                                            break
                                        }
                                    }

                                    // If we didn't find one, add a custom frame rate for the current value
                                    if (!found) {
                                        currentIndex = addRefreshRateOrdered(model, saved_fps, qsTr("Custom (%1 FPS)").arg(saved_fps), true)
                                    }
                                    else {
                                        addRefreshRateOrdered(model, "", qsTr("Custom"), true)
                                    }

                                    recalculateWidth()

                                    lastIndexValue = currentIndex
                                }

                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    reinitialize()
                                    settingsPage.languageChanged.connect(reinitialize)
                                }

                                model: ListModel {
                                    id: fpsListModel
                                    // Other elements may be added at runtime
                                    ListElement {
                                        text: qsTr("30 FPS")
                                        video_fps: "30"
                                        is_custom: false
                                    }
                                    ListElement {
                                        text: qsTr("60 FPS")
                                        video_fps: "60"
                                        is_custom: false
                                    }
                                }

                                id: fpsComboBox
                                maximumWidth: 200
                                textRole: "text"
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    if (model.get(currentIndex).is_custom) {
                                        customFpsDialog.open()
                                    }
                                    else {
                                        updateBitrateForSelection()
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Video bitrate")
                            subtitle: qsTr("Lower the bitrate on slower connections. Raise the bitrate to increase image quality.")

                            Text {
                                text: qsTr("%1 Mbps").arg(slider.value / 1000.0)
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            below: RowLayout {
                                width: parent.width
                                spacing: 12

                                SettingsSlider {
                                    id: slider

                                    value: StreamingPreferences.bitrateKbps

                                    stepSize: 500
                                    from : 500
                                    to: StreamingPreferences.unlockBitrate ? 500000 : 150000

                                    snapMode: Slider.SnapOnRelease
                                    Layout.fillWidth: true

                                    onValueChanged: {
                                        StreamingPreferences.bitrateKbps = value
                                    }

                                    onMoved: {
                                        StreamingPreferences.autoAdjustBitrate = false
                                    }
                                }

                                T.AbstractButton {
                                    id: resetBitrateButton

                                    readonly property int defaultBitrate: StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                                 StreamingPreferences.height,
                                                                                                                 StreamingPreferences.fps,
                                                                                                                 StreamingPreferences.enableYUV444)

                                    text: qsTr("Use Default (%1 Mbps)").arg(defaultBitrate / 1000.0)
                                    visible: StreamingPreferences.bitrateKbps !== defaultBitrate
                                    implicitWidth: resetLabel.implicitWidth + 20
                                    implicitHeight: 24
                                    hoverEnabled: true
                                    activeFocusOnTab: true

                                    contentItem: Text {
                                        id: resetLabel
                                        text: resetBitrateButton.text
                                        color: "white"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        radius: height / 2
                                        color: Qt.rgba(1, 1, 1, resetBitrateButton.pressed ? 0.2 : (resetBitrateButton.hovered ? 0.14 : 0.09))
                                        border.color: resetBitrateButton.palette.highlight
                                        border.width: resetBitrateButton.visualFocus ? 2 : 0
                                    }

                                    onClicked: {
                                        StreamingPreferences.bitrateKbps = defaultBitrate
                                        StreamingPreferences.autoAdjustBitrate = true
                                        slider.value = defaultBitrate
                                    }

                                    Keys.onReturnPressed: clicked()
                                    Keys.onEnterPressed: clicked()
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Display mode")
                            subtitle: qsTr("Fullscreen generally provides the best performance, but borderless windowed may work better with features like macOS Spaces, Alt+Tab, screenshot tools, on-screen overlays, etc.")
                            visible: SystemProperties.hasDesktopEnvironment

                            SettingsComboBox {
                                function createModel() {
                                    var model = Qt.createQmlObject('import QtQuick 2.0; ListModel {}', parent, '')

                                    model.append({
                                                     text: qsTr("Fullscreen"),
                                                     val: StreamingPreferences.WM_FULLSCREEN
                                                 })

                                    model.append({
                                                     text: qsTr("Borderless windowed"),
                                                     val: StreamingPreferences.WM_FULLSCREEN_DESKTOP
                                                 })

                                    model.append({
                                                     text: qsTr("Windowed"),
                                                     val: StreamingPreferences.WM_WINDOWED
                                                 })


                                    // Set the recommended option based on the OS
                                    for (var i = 0; i < model.count; i++) {
                                        var thisWm = model.get(i).val;
                                        if (thisWm === StreamingPreferences.recommendedFullScreenMode) {
                                            model.get(i).text += " " + qsTr("(Recommended)")
                                            model.move(i, 0, 1)
                                            break
                                        }
                                    }

                                    return model
                                }

                                // This is used on initialization and upon retranslation
                                function reinitialize() {
                                    if (!SystemProperties.hasDesktopEnvironment) {
                                        // Do nothing if the control won't even be visible
                                        return
                                    }

                                    model = createModel()
                                    currentIndex = 0

                                    // Set the current value based on the saved preferences
                                    var savedWm = StreamingPreferences.windowMode
                                    for (var i = 0; i < model.count; i++) {
                                         var thisWm = model.get(i).val;
                                         if (savedWm === thisWm) {
                                             currentIndex = i
                                             break
                                         }
                                    }

                                    activated(currentIndex)
                                }

                                Component.onCompleted: {
                                    reinitialize()
                                    settingsPage.languageChanged.connect(reinitialize)
                                }

                                id: windowModeComboBox
                                maximumWidth: 250
                                enabled: !SystemProperties.rendererAlwaysFullScreen
                                textRole: "text"
                                onActivated: {
                                    StreamingPreferences.windowMode = model.get(currentIndex).val
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("V-Sync")
                            subtitle: qsTr("Disabling V-Sync allows sub-frame rendering latency, but it can display visible tearing")
                            toggleTarget: vsyncCheck

                            SettingsSwitch {
                                id: vsyncCheck
                                checked: StreamingPreferences.enableVsync
                                onCheckedChanged: {
                                    StreamingPreferences.enableVsync = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Frame pacing")
                            subtitle: qsTr("Frame pacing reduces micro-stutter by delaying frames that come in too early")
                            toggleTarget: framePacingCheck
                            enabled: StreamingPreferences.enableVsync

                            SettingsSwitch {
                                id: framePacingCheck
                                checked: StreamingPreferences.enableVsync && StreamingPreferences.framePacing
                                onCheckedChanged: {
                                    StreamingPreferences.framePacing = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Enable HDR")
                            subtitle: enabled ?
                                          qsTr("The stream will be HDR-capable, but some games may require an HDR monitor on your host PC to enable HDR mode.")
                                        :
                                          qsTr("HDR streaming is not supported on this PC.")
                            toggleTarget: enableHdr
                            enabled: SystemProperties.supportsHdr

                            SettingsSwitch {
                                id: enableHdr
                                checked: enabled && StreamingPreferences.enableHdr
                                onCheckedChanged: {
                                    StreamingPreferences.enableHdr = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Show performance stats while streaming")
                            subtitle: qsTr("You can toggle it at any time while streaming using Ctrl+Alt+Shift+S or Select+L1+R1+X.")
                            toggleTarget: showPerformanceOverlay

                            SettingsSwitch {
                                id: showPerformanceOverlay
                                checked: StreamingPreferences.showPerformanceOverlay
                                onCheckedChanged: {
                                    StreamingPreferences.showPerformanceOverlay = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: audioSection
                        title: qsTr("Audio")

                        SettingsRow {
                            title: qsTr("Audio configuration")

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved_audio = StreamingPreferences.audioConfig
                                    currentIndex = 0
                                    for (var i = 0; i < audioListModel.count; i++) {
                                        var el_audio = audioListModel.get(i).val;
                                        if (saved_audio === el_audio) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                    activated(currentIndex)
                                }

                                id: audioComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: audioListModel
                                    ListElement {
                                        text: qsTr("Stereo")
                                        val: StreamingPreferences.AC_STEREO
                                    }
                                    ListElement {
                                        text: qsTr("5.1 surround sound")
                                        val: StreamingPreferences.AC_51_SURROUND
                                    }
                                    ListElement {
                                        text: qsTr("7.1 surround sound")
                                        val: StreamingPreferences.AC_71_SURROUND
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    StreamingPreferences.audioConfig = audioListModel.get(currentIndex).val
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Mute host PC speakers while streaming")
                            subtitle: qsTr("You must restart any game currently in progress for this setting to take effect")
                            toggleTarget: audioPcCheck

                            SettingsSwitch {
                                id: audioPcCheck
                                checked: !StreamingPreferences.playAudioOnHost
                                onCheckedChanged: {
                                    StreamingPreferences.playAudioOnHost = !checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Mute audio stream when Moonlight is not the active window")
                            subtitle: qsTr("Mutes Moonlight's audio when you Alt+Tab out of the stream or click on a different window.")
                            toggleTarget: muteOnFocusLossCheck
                            visible: SystemProperties.hasDesktopEnvironment

                            SettingsSwitch {
                                id: muteOnFocusLossCheck
                                checked: StreamingPreferences.muteOnFocusLoss
                                onCheckedChanged: {
                                    StreamingPreferences.muteOnFocusLoss = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: inputSection
                        title: qsTr("Input")

                        SettingsRow {
                            title: qsTr("Optimize mouse for remote desktop instead of games")
                            subtitle: qsTr("This enables seamless mouse control without capturing the client's mouse cursor. It is ideal for remote desktop usage but will not work in most games.") + " " +
                                      qsTr("You can toggle this while streaming using Ctrl+Alt+Shift+M.")
                            toggleTarget: absoluteMouseCheck

                            SettingsSwitch {
                                id: absoluteMouseCheck
                                checked: StreamingPreferences.absoluteMouseMode
                                onCheckedChanged: {
                                    StreamingPreferences.absoluteMouseMode = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Capture system keyboard shortcuts")
                            subtitle: qsTr("This enables the capture of system-wide keyboard shortcuts like Alt+Tab that would normally be handled by the client OS while streaming.")
                            visible: SystemProperties.hasDesktopEnvironment

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved_syskeysmode = StreamingPreferences.captureSysKeysMode
                                    currentIndex = 0
                                    for (var i = 0; i < captureSysKeysModeListModel.count; i++) {
                                        var el_syskeysmode = captureSysKeysModeListModel.get(i).val;
                                        if (saved_syskeysmode === el_syskeysmode) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }

                                id: captureSysKeysComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: captureSysKeysModeListModel
                                    ListElement {
                                        text: qsTr("Never")
                                        val: StreamingPreferences.CSK_OFF
                                    }
                                    ListElement {
                                        text: qsTr("In fullscreen")
                                        val: StreamingPreferences.CSK_FULLSCREEN
                                    }
                                    ListElement {
                                        text: qsTr("Always")
                                        val: StreamingPreferences.CSK_ALWAYS
                                    }
                                }

                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated: {
                                    StreamingPreferences.captureSysKeysMode = captureSysKeysModeListModel.get(currentIndex).val
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Use touchscreen as a virtual trackpad")
                            subtitle: qsTr("When checked, the touchscreen acts like a trackpad. When unchecked, the touchscreen will directly control the mouse pointer.")
                            toggleTarget: absoluteTouchCheck

                            SettingsSwitch {
                                id: absoluteTouchCheck
                                checked: !StreamingPreferences.absoluteTouchMode
                                onCheckedChanged: {
                                    StreamingPreferences.absoluteTouchMode = !checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Swap left and right mouse buttons")
                            toggleTarget: swapMouseButtonsCheck

                            SettingsSwitch {
                                id: swapMouseButtonsCheck
                                checked: StreamingPreferences.swapMouseButtons
                                onCheckedChanged: {
                                    StreamingPreferences.swapMouseButtons = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Reverse mouse scrolling direction")
                            toggleTarget: reverseScrollButtonsCheck

                            SettingsSwitch {
                                id: reverseScrollButtonsCheck
                                checked: StreamingPreferences.reverseScrollDirection
                                onCheckedChanged: {
                                    StreamingPreferences.reverseScrollDirection = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: gamepadSection
                        title: qsTr("Gamepad")

                        SettingsRow {
                            title: qsTr("Swap A/B and X/Y gamepad buttons")
                            subtitle: qsTr("This switches gamepads into a Nintendo-style button layout")
                            toggleTarget: swapFaceButtonsCheck

                            SettingsSwitch {
                                id: swapFaceButtonsCheck
                                checked: StreamingPreferences.swapFaceButtons
                                onCheckedChanged: {
                                    StreamingPreferences.swapFaceButtons = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Force gamepad #1 always connected")
                            subtitle: qsTr("Only enable this option when streaming a game that doesn't support gamepads being connected after startup.")
                            toggleTarget: singleControllerCheck

                            SettingsSwitch {
                                id: singleControllerCheck
                                checked: !StreamingPreferences.multiController
                                onCheckedChanged: {
                                    StreamingPreferences.multiController = !checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Enable mouse control with gamepads by holding the 'Start' button")
                            toggleTarget: gamepadMouseCheck

                            SettingsSwitch {
                                id: gamepadMouseCheck
                                checked: StreamingPreferences.gamepadMouse
                                onCheckedChanged: {
                                    StreamingPreferences.gamepadMouse = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Process gamepad input when Moonlight is in the background")
                            subtitle: qsTr("Allows Moonlight to capture gamepad inputs even if it's not the current window in focus")
                            toggleTarget: backgroundGamepadCheck
                            visible: SystemProperties.hasDesktopEnvironment

                            SettingsSwitch {
                                id: backgroundGamepadCheck
                                checked: StreamingPreferences.backgroundGamepad
                                onCheckedChanged: {
                                    StreamingPreferences.backgroundGamepad = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: hostSection
                        title: qsTr("Host")

                        SettingsRow {
                            title: qsTr("Optimize game settings for streaming")
                            toggleTarget: optimizeGameSettingsCheck

                            SettingsSwitch {
                                id: optimizeGameSettingsCheck
                                checked: StreamingPreferences.gameOptimizations
                                onCheckedChanged: {
                                    StreamingPreferences.gameOptimizations = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Quit app on host PC after ending stream")
                            subtitle: qsTr("This will close the app or game you are streaming when you end your stream. You will lose any unsaved progress!")
                            toggleTarget: quitAppAfter

                            SettingsSwitch {
                                id: quitAppAfter
                                checked: StreamingPreferences.quitAppAfter
                                onCheckedChanged: {
                                    StreamingPreferences.quitAppAfter = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: networkSection
                        title: qsTr("Network")

                        SettingsRow {
                            title: qsTr("Disable AirDrop while streaming")
                            subtitle: qsTr("Temporarily disables AirDrop and other AWDL features while streaming to prevent Wi-Fi latency spikes. Installs a small background helper the first time, which requires administrator approval once.")
                            toggleTarget: disableAwdlCheck
                            visible: Qt.platform.os === "osx"

                            SettingsSwitch {
                                id: disableAwdlCheck
                                checked: StreamingPreferences.disableAwdl
                                onCheckedChanged: {
                                    StreamingPreferences.disableAwdl = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Automatically find PCs on the local network (Recommended)")
                            toggleTarget: enableMdns

                            SettingsSwitch {
                                id: enableMdns
                                checked: StreamingPreferences.enableMdns
                                onCheckedChanged: {
                                    // This is called on init, so only do the work if we've
                                    // actually changed the value.
                                    if (StreamingPreferences.enableMdns != checked) {
                                        StreamingPreferences.enableMdns = checked

                                        // Restart polling so the mDNS change takes effect
                                        if (window.pollingActive) {
                                            ComputerManager.stopPollingAsync()
                                            ComputerManager.startPolling()
                                        }
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Automatically detect blocked connections (Recommended)")
                            toggleTarget: detectNetworkBlocking

                            SettingsSwitch {
                                id: detectNetworkBlocking
                                checked: StreamingPreferences.detectNetworkBlocking
                                onCheckedChanged: {
                                    StreamingPreferences.detectNetworkBlocking = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Show connection quality warnings")
                            toggleTarget: connectionWarningsCheck

                            SettingsSwitch {
                                id: connectionWarningsCheck
                                checked: StreamingPreferences.connectionWarnings
                                onCheckedChanged: {
                                    StreamingPreferences.connectionWarnings = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: generalSection
                        title: qsTr("General")

                        SettingsRow {
                            title: qsTr("Language")

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved_language = StreamingPreferences.language
                                    currentIndex = 0
                                    for (var i = 0; i < languageListModel.count; i++) {
                                        var el_language = languageListModel.get(i).val;
                                        if (saved_language === el_language) {
                                            currentIndex = i
                                            break
                                        }
                                    }

                                    activated(currentIndex)
                                }

                                id: languageComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: languageListModel
                                    ListElement {
                                        text: qsTr("Automatic")
                                        val: StreamingPreferences.LANG_AUTO
                                    }
                                    ListElement {
                                        text: "Deutsch" // German
                                        val: StreamingPreferences.LANG_DE
                                    }
                                    ListElement {
                                        text: "English"
                                        val: StreamingPreferences.LANG_EN
                                    }
                                    ListElement {
                                        text: "Français" // French
                                        val: StreamingPreferences.LANG_FR
                                    }
                                    ListElement {
                                        text: "简体中文" // Simplified Chinese
                                        val: StreamingPreferences.LANG_ZH_CN
                                    }
                                    ListElement {
                                        text: "Norwegian Bokmål"
                                        val: StreamingPreferences.LANG_NB_NO
                                    }
                                    ListElement {
                                        text: "русский" // Russian
                                        val: StreamingPreferences.LANG_RU
                                    }
                                    ListElement {
                                        text: "Español" // Spanish
                                        val: StreamingPreferences.LANG_ES
                                    }
                                    ListElement {
                                        text: "日本語" // Japanese
                                        val: StreamingPreferences.LANG_JA
                                    }
                                    ListElement {
                                        text: "Tiếng Việt" // Vietnamese
                                        val: StreamingPreferences.LANG_VI
                                    }
                                    ListElement {
                                        text: "ภาษาไทย" // Thai
                                        val: StreamingPreferences.LANG_TH
                                    }
                                    ListElement {
                                        text: "한국어" // Korean
                                        val: StreamingPreferences.LANG_KO
                                    }
                                    ListElement {
                                        text: "Magyar" // Hungarian
                                        val: StreamingPreferences.LANG_HU
                                    }
                                    ListElement {
                                        text: "Nederlands" // Dutch
                                        val: StreamingPreferences.LANG_NL
                                    }
                                    ListElement {
                                        text: "Svenska" // Swedish
                                        val: StreamingPreferences.LANG_SV
                                    }
                                    ListElement {
                                        text: "Türkçe" // Turkish
                                        val: StreamingPreferences.LANG_TR
                                    }
                                    /* ListElement {
                                        text: "Українська" // Ukrainian
                                        val: StreamingPreferences.LANG_UK
                                    } */
                                    ListElement {
                                        text: "繁體中文" // Traditional Chinese
                                        val: StreamingPreferences.LANG_ZH_TW
                                    }
                                    ListElement {
                                        text: "Português" // Portuguese
                                        val: StreamingPreferences.LANG_PT
                                    }
                                    ListElement {
                                        text: "Português do Brasil" // Brazilian Portuguese
                                        val: StreamingPreferences.LANG_PT_BR
                                    }
                                    ListElement {
                                        text: "Ελληνικά" // Greek
                                        val: StreamingPreferences.LANG_EL
                                    }
                                    ListElement {
                                        text: "Italiano" // Italian
                                        val: StreamingPreferences.LANG_IT
                                    }
                                    /* ListElement {
                                        text: "हिन्दी, हिंदी" // Hindi
                                        val: StreamingPreferences.LANG_HI
                                    } */
                                    ListElement {
                                        text: "Język polski" // Polish
                                        val: StreamingPreferences.LANG_PL
                                    }
                                    ListElement {
                                        text: "Čeština" // Czech
                                        val: StreamingPreferences.LANG_CS
                                    }
                                    /* ListElement {
                                        text: "עִבְרִית" // Hebrew
                                        val: StreamingPreferences.LANG_HE
                                    } */
                                    /* ListElement {
                                        text: "کرمانجیی خواروو" // Central Kurdish
                                        val: StreamingPreferences.LANG_CKB
                                    } */
                                    /* ListElement {
                                        text: "Lietuvių kalba" // Lithuanian
                                        val: StreamingPreferences.LANG_LT
                                    } */
                                    /* ListElement {
                                        text: "Eesti" // Estonian
                                        val: StreamingPreferences.LANG_ET
                                    } */
                                    ListElement {
                                        text: "Български" // Bulgarian
                                        val: StreamingPreferences.LANG_BG
                                    }
                                    /* ListElement {
                                        text: "Esperanto"
                                        val: StreamingPreferences.LANG_EO
                                    } */
                                    ListElement {
                                        text: "தமிழ்" // Tamil
                                        val: StreamingPreferences.LANG_TA
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    // Retranslating is expensive, so only do it if the language actually changed
                                    var new_language = languageListModel.get(currentIndex).val
                                    if (StreamingPreferences.language !== new_language) {
                                        StreamingPreferences.language = languageListModel.get(currentIndex).val
                                        if (!StreamingPreferences.retranslate()) {
                                            ToolTip.show(qsTr("You must restart Moonlight for this change to take effect"), 5000)
                                        }
                                        else {
                                            // Pop any AppView pages that exist underneath us.
                                            // The AppView stops working after retranslate() for some reason.
                                            if (stackView.depth > 1) {
                                                stackView.pop(null)
                                            }

                                            // Signal other controls to adjust their text
                                            settingsPage.languageChanged()
                                        }
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("GUI display mode")
                            visible: SystemProperties.hasDesktopEnvironment

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    if (!SystemProperties.hasDesktopEnvironment) {
                                        // Do nothing if the control won't even be visible
                                        return
                                    }

                                    var saved_uidisplaymode = StreamingPreferences.uiDisplayMode
                                    currentIndex = 0
                                    for (var i = 0; i < uiDisplayModeListModel.count; i++) {
                                        var el_uidisplaymode = uiDisplayModeListModel.get(i).val;
                                        if (saved_uidisplaymode === el_uidisplaymode) {
                                            currentIndex = i
                                            break
                                        }
                                    }

                                    activated(currentIndex)
                                }

                                id: uiDisplayModeComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: uiDisplayModeListModel
                                    ListElement {
                                        text: qsTr("Windowed")
                                        val: StreamingPreferences.UI_WINDOWED
                                    }
                                    ListElement {
                                        text: qsTr("Maximized")
                                        val: StreamingPreferences.UI_MAXIMIZED
                                    }
                                    ListElement {
                                        text: qsTr("Fullscreen")
                                        val: StreamingPreferences.UI_FULLSCREEN
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    StreamingPreferences.uiDisplayMode = uiDisplayModeListModel.get(currentIndex).val
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Keep the display awake while streaming")
                            subtitle: qsTr("Prevents the screensaver from starting or the display from going to sleep while streaming.")
                            toggleTarget: keepAwakeCheck

                            SettingsSwitch {
                                id: keepAwakeCheck
                                checked: StreamingPreferences.keepAwake
                                onCheckedChanged: {
                                    StreamingPreferences.keepAwake = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Show configuration warnings")
                            toggleTarget: configurationWarningsCheck

                            SettingsSwitch {
                                id: configurationWarningsCheck
                                checked: StreamingPreferences.configurationWarnings
                                onCheckedChanged: {
                                    StreamingPreferences.configurationWarnings = checked
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Discord Rich Presence integration")
                            subtitle: qsTr("Updates your Discord status to display the name of the game you're streaming.")
                            toggleTarget: discordPresenceCheck
                            visible: SystemProperties.hasDiscordIntegration

                            SettingsSwitch {
                                id: discordPresenceCheck
                                checked: StreamingPreferences.richPresence
                                onCheckedChanged: {
                                    StreamingPreferences.richPresence = checked
                                }
                            }
                        }
                    }

                    SettingsSection {
                        id: advancedSection
                        title: qsTr("Advanced")

                        SettingsRow {
                            title: qsTr("Video decoder")

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved_vds = StreamingPreferences.videoDecoderSelection
                                    currentIndex = 0
                                    for (var i = 0; i < decoderListModel.count; i++) {
                                        var el_vds = decoderListModel.get(i).val;
                                        if (saved_vds === el_vds) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                    activated(currentIndex)
                                }

                                id: decoderComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: decoderListModel
                                    ListElement {
                                        text: qsTr("Automatic (Recommended)")
                                        val: StreamingPreferences.VDS_AUTO
                                    }
                                    ListElement {
                                        text: qsTr("Force software decoding")
                                        val: StreamingPreferences.VDS_FORCE_SOFTWARE
                                    }
                                    ListElement {
                                        text: qsTr("Force hardware decoding")
                                        val: StreamingPreferences.VDS_FORCE_HARDWARE
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated: {
                                    if (enabled) {
                                        StreamingPreferences.videoDecoderSelection = decoderListModel.get(currentIndex).val
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Video codec")

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved_vcc = StreamingPreferences.videoCodecConfig

                                    // Default to Automatic (relevant if HDR is enabled,
                                    // where we will match none of the codecs in the list)
                                    currentIndex = 0

                                    for(var i = 0; i < codecListModel.count; i++) {
                                        var el_vcc = codecListModel.get(i).val;
                                        if (saved_vcc === el_vcc) {
                                            currentIndex = i
                                            break
                                        }
                                    }

                                    activated(currentIndex)
                                }

                                id: codecComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: codecListModel
                                    ListElement {
                                        text: qsTr("Automatic (Recommended)")
                                        val: StreamingPreferences.VCC_AUTO
                                    }
                                    ListElement {
                                        text: qsTr("H.264")
                                        val: StreamingPreferences.VCC_FORCE_H264
                                    }
                                    ListElement {
                                        text: qsTr("HEVC (H.265)")
                                        val: StreamingPreferences.VCC_FORCE_HEVC
                                    }
                                    ListElement {
                                        text: qsTr("AV1")
                                        val: StreamingPreferences.VCC_FORCE_AV1
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    if (enabled) {
                                        StreamingPreferences.videoCodecConfig = codecListModel.get(currentIndex).val
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Renderer")
                            visible: SystemProperties.isDarwin

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved_rs = StreamingPreferences.rendererSelection

                                    // Default to Automatic
                                    currentIndex = 0

                                    for(var i = 0; i < rendererListModel.count; i++) {
                                        var el_rs = rendererListModel.get(i).val;
                                        if (saved_rs === el_rs) {
                                            currentIndex = i
                                            break
                                        }
                                    }

                                    activated(currentIndex)
                                }

                                id: rendererComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: rendererListModel
                                    ListElement {
                                        text: qsTr("Automatic (Recommended)")
                                        val: StreamingPreferences.RS_AUTO
                                    }
                                    ListElement {
                                        text: "Vulkan"
                                        val: StreamingPreferences.RS_VULKAN
                                    }
                                    ListElement {
                                        text: "Metal"
                                        val: StreamingPreferences.RS_METAL
                                    }
                                    ListElement {
                                        text: "AVSampleBufferDisplayLayer"
                                        val: StreamingPreferences.RS_AVSBDL
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    StreamingPreferences.rendererSelection = rendererListModel.get(currentIndex).val
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Frame latency")
                            subtitle: qsTr("Trade presentation latency for smoother frame delivery.")
                            visible: SystemProperties.isDarwin

                            SettingsComboBox {
                                // ignore setting the index at first, and actually set it when the component is loaded
                                Component.onCompleted: {
                                    var saved = StreamingPreferences.frameLatencyMode

                                    currentIndex = 0

                                    for (var i = 0; i < latencyListModel.count; i++) {
                                        if (latencyListModel.get(i).val === saved) {
                                            currentIndex = i
                                            break
                                        }
                                    }

                                    activated(currentIndex)
                                }

                                id: latencyComboBox
                                textRole: "text"
                                model: ListModel {
                                    id: latencyListModel
                                    ListElement {
                                        text: qsTr("Default")
                                        val: StreamingPreferences.FLM_DEFAULT
                                    }
                                    ListElement {
                                        text: qsTr("Fast (lowest latency)")
                                        val: StreamingPreferences.FLM_FAST
                                    }
                                    ListElement {
                                        text: qsTr("Balanced")
                                        val: StreamingPreferences.FLM_BALANCED
                                    }
                                    ListElement {
                                        text: qsTr("Smooth")
                                        val: StreamingPreferences.FLM_SMOOTH
                                    }
                                }
                                // ::onActivated must be used, as it only listens for when the index is changed by a human
                                onActivated : {
                                    StreamingPreferences.frameLatencyMode = latencyListModel.get(currentIndex).val
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Enable YUV 4:4:4")
                            subtitle: qsTr("Good for streaming desktop and text-heavy games, but not recommended for fast-paced games.")
                            toggleTarget: enableYUV444

                            SettingsSwitch {
                                id: enableYUV444
                                checked: StreamingPreferences.enableYUV444
                                onCheckedChanged: {
                                    // This is called on init, so only reset to default bitrate when checked state changes.
                                    if (StreamingPreferences.enableYUV444 != checked) {
                                        StreamingPreferences.enableYUV444 = checked
                                        if (StreamingPreferences.autoAdjustBitrate) {
                                            StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(StreamingPreferences.width,
                                                                                                                      StreamingPreferences.height,
                                                                                                                      StreamingPreferences.fps,
                                                                                                                      StreamingPreferences.enableYUV444);
                                            slider.value = StreamingPreferences.bitrateKbps
                                        }
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            title: qsTr("Unlock bitrate limit (Experimental)")
                            subtitle: qsTr("This unlocks extremely high video bitrates for use with Sunshine hosts. It should only be used when streaming over an Ethernet LAN connection.")
                            toggleTarget: unlockBitrate

                            SettingsSwitch {
                                id: unlockBitrate
                                checked: StreamingPreferences.unlockBitrate
                                onCheckedChanged: {
                                    StreamingPreferences.unlockBitrate = checked
                                    StreamingPreferences.bitrateKbps = Math.min(StreamingPreferences.bitrateKbps, slider.to)
                                    slider.value = StreamingPreferences.bitrateKbps
                                }
                            }
                        }
                    }

                    // Version and links
                    Column {
                        width: parent.width
                        spacing: 8
                        topPadding: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Version %1").arg(SystemProperties.versionString)
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 12
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 16
                            visible: SystemProperties.hasBrowser

                            Repeater {
                                model: [
                                    { "text": qsTr("Help"), "url": "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide" },
                                    { "text": qsTr("Discord"), "url": "https://moonlight-stream.org/discord" }
                                ]

                                Text {
                                    required property var modelData

                                    text: modelData.text
                                    color: linkMouseArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.55)
                                    font.pixelSize: 12
                                    font.underline: linkMouseArea.containsMouse

                                    MouseArea {
                                        id: linkMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally(parent.modelData.url)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
