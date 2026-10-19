import AppKit
import SwiftUI

/// The menu bar extra: open sessions, every computer with a one-click action,
/// and the usual app items.
struct MenuBarContent: View {
    @Environment(HostStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Starlight")
                    .font(.headline)
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            ForEach(store.sessions, id: \.request) { session in
                ActiveSessionRow(session: session)
            }

            if !store.hosts.isEmpty {
                Text("Computers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)

                ForEach(store.hosts) { host in
                    MenuBarHostRow(host: host)
                }
            }

            Divider()
                .padding(.vertical, 2)

            MenuItemButton("Open Starlight", shortcut: "⌘O") {
                openWindow(id: WindowID.computers)
                NSApp.activate()
            }
            .keyboardShortcut("o")

            SettingsLink {
                MenuItemLabel(title: "Settings…", shortcut: "⌘,")
            }
            .buttonStyle(MenuItemButtonStyle())

            MenuItemButton("Quit Starlight", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 320)
    }
}

private struct ActiveSessionRow: View {
    var session: SessionModel

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: .green)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.host.name)
                    .fontWeight(.semibold)
                Text(session.state == .connecting ? "Connecting…" : "Connected · \(session.app.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Show") { session.bringToFront() }
            Button {
                session.disconnect()
            } label: {
                Image(systemName: "power")
            }
            .help("Disconnect")
            .accessibilityLabel("Disconnect from \(session.host.name)")
        }
        .controlSize(.small)
        .padding(10)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct MenuBarHostRow: View {
    var host: RemoteHost

    @Environment(HostStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "display")
                .font(.system(size: 15))
                .frame(width: 20)
                .foregroundStyle(host.isReachable ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(host.name)
                HStack(spacing: 4) {
                    StatusDot(color: host.statusColor)
                    Text(shortStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            action
                .controlSize(.small)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .opacity(host.status == .offline && !host.canWake ? 0.55 : 1)
    }

    private var shortStatus: String {
        switch host.status {
        case .unknown: return "Checking…"
        case .online: return "Online"
        case .busy: return "\(host.runningApp?.name ?? "App") running"
        case .offline: return store.isWaking(host) ? "Waking…" : "Offline"
        case .unpaired: return "Not paired"
        }
    }

    @ViewBuilder
    private var action: some View {
        switch host.status {
        case .online, .busy:
            Button("Connect") {
                if let request = store.connect(to: host) {
                    openWindow(id: WindowID.session, value: request)
                    NSApp.activate()
                }
            }
        case .offline:
            if host.canWake {
                Button("Wake") { store.wake(host) }
                    .disabled(store.isWaking(host))
            }
        case .unpaired:
            Button("Pair…") {
                openWindow(id: WindowID.computers)
                NSApp.activate()
                store.beginPairing(with: host)
            }
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Menu-style rows

private struct MenuItemButton: View {
    var title: String
    var shortcut: String
    var action: () -> Void

    init(_ title: String, shortcut: String, action: @escaping () -> Void) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            MenuItemLabel(title: title, shortcut: shortcut)
        }
        .buttonStyle(MenuItemButtonStyle())
    }
}

private struct MenuItemLabel: View {
    var title: String
    var shortcut: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .foregroundStyle(.secondary)
        }
    }
}

/// Full-width rows that highlight on hover, like menu items.
private struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverHighlight(isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct HoverHighlight<Content: View>: View {
    var isPressed: Bool
    @ViewBuilder var content: Content

    @State private var isHovering = false

    var body: some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isHovering ? AnyShapeStyle(Color.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovering ? Color.accentColor.opacity(isPressed ? 0.8 : 1) : .clear)
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}
