import SwiftUI

public enum WindowID {
    public static let computers = "computers"
    public static let session = "session"
}

/// All of Starlight's scenes: the Computers window, stream windows, Settings
/// and the menu bar extra.
///
/// An app only needs to create a `HostStore` and return this from its `body`,
/// so swapping the mock services for the real ones is a change in one place.
public struct StarlightScenes: Scene {
    private let store: HostStore
    private let defaults: UserDefaults

    /// - Parameters:
    ///   - store: App state, backed by the host service of your choice.
    ///   - defaults: Where Settings reads and writes preferences. Pass
    ///     `.standard` when running as the real app so the core sees them.
    public init(store: HostStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    public var body: some Scene {
        Window("Starlight", id: WindowID.computers) {
            ComputersView()
                .environment(store)
                .defaultAppStorage(defaults)
        }
        .defaultSize(width: 560, height: 620)
        .commands {
            StarlightCommands(store: store)
        }

        WindowGroup("Stream", id: WindowID.session, for: SessionRequest.self) { $request in
            SessionWindow(request: request)
                .environment(store)
                .defaultAppStorage(defaults)
        }
        .defaultSize(width: 1280, height: 760)

        Settings {
            SettingsView()
                .environment(store)
                .defaultAppStorage(defaults)
        }

        MenuBarExtra("Starlight", systemImage: "display") {
            MenuBarContent()
                .environment(store)
                .defaultAppStorage(defaults)
        }
        .menuBarExtraStyle(.window)
    }
}
