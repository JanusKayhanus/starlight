import QtQuick
import QtQuick.Window
import Qt.labs.platform as Platform

// Native macOS menu bar. This lives in main.qml's context, so it uses the ids declared there.
Platform.MenuBar {
    // MenuBar has its own window property, which would shadow main.qml's window id
    readonly property var appWindow: stackView.Window.window

    Platform.Menu {
        title: qsTr("File")

        Platform.MenuItem {
            text: qsTr("Add PC…")
            shortcut: StandardKey.New
            enabled: stackView.currentItem instanceof LauncherView
            onTriggered: addPcDialog.open()
        }
    }

    Platform.Menu {
        title: qsTr("View")

        Platform.MenuItem {
            text: qsTr("Back")
            shortcut: "Ctrl+["
            enabled: stackView.depth > 1
            onTriggered: goBack()
        }

        Platform.MenuSeparator {}

        Platform.MenuItem {
            text: appWindow.visibility === Window.FullScreen ? qsTr("Exit Full Screen") : qsTr("Enter Full Screen")
            shortcut: StandardKey.FullScreen
            onTriggered: {
                if (appWindow.visibility === Window.FullScreen) {
                    appWindow.showNormal()
                }
                else {
                    appWindow.showFullScreen()
                }
            }
        }

        // Settings… is moved into the application menu by Qt
        Platform.MenuItem {
            text: qsTr("Settings…")
            role: Platform.MenuItem.PreferencesRole
            shortcut: StandardKey.Preferences
            onTriggered: settingsButton.clicked()
        }
    }

    Platform.Menu {
        title: qsTr("Window")

        Platform.MenuItem {
            text: qsTr("Minimize")
            shortcut: "Ctrl+M"
            onTriggered: appWindow.showMinimized()
        }

        Platform.MenuItem {
            text: qsTr("Zoom")
            onTriggered: {
                if (appWindow.visibility === Window.Maximized) {
                    appWindow.showNormal()
                }
                else {
                    appWindow.showMaximized()
                }
            }
        }
    }

    Platform.Menu {
        title: qsTr("Help")

        Platform.MenuItem {
            text: qsTr("Moonlight Setup Guide")
            shortcut: StandardKey.HelpContents
            onTriggered: Qt.openUrlExternally("https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide")
        }

        Platform.MenuItem {
            text: qsTr("Troubleshooting Guide")
            onTriggered: Qt.openUrlExternally("https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting")
        }

        Platform.MenuSeparator {}

        Platform.MenuItem {
            text: qsTr("Join the Moonlight Discord")
            onTriggered: Qt.openUrlExternally("https://moonlight-stream.org/discord")
        }
    }
}
