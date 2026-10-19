import AppKit
import StarlightUI
import SwiftUI

/// Runs the Starlight UI against mock services. Nothing here talks to a real
/// host or to the streaming core.
@main
struct MockStarlightApp: App {
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
                              makeStreamController: { MockStreamController(hostService: hostService) })
        store.start()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        StarlightScenes(store: store, defaults: defaults)
    }
}
