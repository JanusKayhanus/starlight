import AppKit
import StarlightUI
import SwiftUI

/// The real Starlight app: the UI on top of the streaming core. Streams play
/// in the Moonlight client's own window.
@main
struct StarlightApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: StarlightAppDelegate
    @State private var store: HostStore

    /// The preferences the core reads, so Settings edits what the client uses.
    private let defaults = StarlightApp.coreDefaults

    init() {
        // Under `swift run` this is a plain executable rather than an app
        // bundle, so ask for a Dock icon and a menu bar explicitly.
        NSApplication.shared.setActivationPolicy(.regular)

        let service = CoreHostService(isDiscoveryEnabled: {
            // Same default as the core's StreamingPreferences.
            StarlightApp.coreDefaults.object(forKey: PreferenceKey.mdns) as? Bool ?? true
        })
        let store = HostStore(service: service, makeStreamController: { ClientStreamController() })
        store.opensStreamWindows = false
        store.start()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        StarlightScenes(store: store, defaults: defaults)
    }

    /// The core's preferences domain. Inside Moonlight.app that's the app's
    /// own (standard) defaults; UserDefaults won't open the app's own bundle
    /// identifier as a suite.
    nonisolated static var coreDefaults: UserDefaults {
        let domain = "com.moonlight-stream.Moonlight"
        if Bundle.main.bundleIdentifier == domain {
            return .standard
        }
        return UserDefaults(suiteName: domain) ?? .standard
    }
}

final class StarlightAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Stream windows aren't documents; keep Show Tab Bar out of the View menu.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opened from a terminal, the terminal stays the active app.
        NSApp.activate()
    }
}
