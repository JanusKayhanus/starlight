import AppKit
import SwiftUI

/// Menu bar commands. Stream controls go in the View menu, next to the
/// system's own Enter Full Screen (⌃⌘F), which SwiftUI adds automatically.
struct StarlightCommands: Commands {
    var store: HostStore

    @FocusedValue(\.session) private var session
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Computer…") {
                openWindow(id: WindowID.computers)
                store.isAddingComputer = true
            }
            .keyboardShortcut("n")

            // Lives in this group because `.saveItem` placements don't show
            // up in an app without documents.
            if let session {
                Divider()
                Button("Disconnect from \(session.host.name)") {
                    session.disconnect()
                }
            }
        }

        CommandGroup(before: .toolbar) {
            Picker("Scaling", selection: scaling) {
                ForEach(ScalingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .disabled(session == nil)

            Menu("Move to Display") {
                ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                    moveButton(index: index, screen: screen)
                }
            }
            .disabled(session == nil || NSScreen.screens.count < 2)

            Divider()
        }
    }

    private var scaling: Binding<ScalingMode> {
        Binding {
            session?.scaling ?? .fit
        } set: { mode in
            session?.setScaling(mode)
        }
    }

    @ViewBuilder
    private func moveButton(index: Int, screen: NSScreen) -> some View {
        let button = Button(screen.localizedName) {
            session?.move(to: screen)
        }
        if index < 9 {
            button.keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .control])
        } else {
            button
        }
    }
}
