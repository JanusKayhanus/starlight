import AppKit
import StarlightUI
import SwiftUI

/// Runs the Starlight UI against mock services. Nothing here talks to a real
/// host or to the streaming core.
@main
struct MockStarlightApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MockAppDelegate
    @State private var store: HostStore

    /// A separate preferences suite, so the mock never edits the real app's
    /// streaming preferences.
    private let defaults = UserDefaults(suiteName: "com.moonlight-stream.Moonlight.ui-mock") ?? .standard

    init() {
        // `swift run` starts a plain executable rather than an app bundle, so
        // ask for a Dock icon and a menu bar explicitly.
        NSApplication.shared.setActivationPolicy(.regular)

        let hostService = MockHostService()
        let store = HostStore(service: hostService,
                              makeStreamController: { HardcodedHostStreamController(hostService: hostService) })
        store.start()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        StarlightScenes(store: store, defaults: defaults)
    }
}

final class MockAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Stream windows aren't documents; keep Show Tab Bar out of the View menu.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` launches the executable from a terminal, which stays the
        // active app, so bring the mock to the front once it has launched.
        NSApp.activate()
    }
}
