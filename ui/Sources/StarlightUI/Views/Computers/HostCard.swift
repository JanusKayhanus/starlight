import SwiftUI

/// One computer in the Computers window: a header row with Connect (or Wake,
/// or Pair), which expands to list the host's apps.
struct HostCard: View {
    var host: RemoteHost

    @Environment(HostStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    private var isExpanded: Bool {
        store.expandedHostIDs.contains(host.id)
    }

    private var canExpand: Bool {
        host.isPaired && host.isReachable && !host.apps.isEmpty
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        VStack(spacing: 0) {
            header

            if isExpanded && canExpand {
                Divider()
                VStack(spacing: 0) {
                    ForEach(host.apps) { app in
                        AppRow(app: app,
                               isRunning: host.runningApp?.id == app.id,
                               isSelected: store.selectedApp(for: host)?.id == app.id,
                               select: { store.selectedAppIDs[host.id] = app.id },
                               launch: { connect(app) })
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color.primary.opacity(isExpanded ? 0.07 : 0.05), in: shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .clipShape(shape)
        .opacity(host.status == .offline ? 0.6 : 1)
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            HostThumbnail(host: host)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .font(.headline)
                HStack(spacing: 5) {
                    StatusDot(color: host.statusColor)
                    Text(host.statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            primaryButton

            Button {
                withAnimation(.snappy(duration: 0.2)) { toggleExpanded() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    // A plain button doesn't dim its label when disabled.
                    .foregroundStyle(canExpand ? HierarchicalShapeStyle.secondary : .quaternary)
                    .rotationEffect(.degrees(isExpanded && canExpand ? 90 : 0))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canExpand)
            .accessibilityLabel(isExpanded ? "Hide apps" : "Show apps")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if host.isPaired && host.isReachable {
                connect(nil)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch host.status {
        case .online, .busy:
            if isExpanded {
                Button("Connect") { connect(nil) }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Connect") { connect(nil) }
                    .buttonStyle(.bordered)
            }
        case .offline:
            Button(store.isWaking(host) ? "Waking…" : "Wake") { store.wake(host) }
                .buttonStyle(.bordered)
                .disabled(!host.canWake || store.isWaking(host))
        case .unpaired:
            Button("Pair…") { store.beginPairing(with: host) }
                .buttonStyle(.bordered)
        case .unknown:
            ProgressView()
                .controlSize(.small)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenu: some View {
        if host.isPaired && host.isReachable {
            Button("Connect") { connect(nil) }
            if !host.apps.isEmpty {
                Menu("Connect To") {
                    ForEach(host.apps) { app in
                        Button(app.name) { connect(app) }
                    }
                }
            }
        }
        if host.status == .offline && host.canWake {
            Button("Wake") { store.wake(host) }
        }
        if host.status == .unpaired {
            Button("Pair…") { store.beginPairing(with: host) }
        }
        if let running = host.runningApp {
            Button("Quit \(running.name)") { store.quitApp(on: host) }
        }
        Divider()
        Button("Remove “\(host.name)”", role: .destructive) { store.forget(host) }
    }

    // MARK: - Actions

    private func toggleExpanded() {
        if isExpanded {
            store.expandedHostIDs.remove(host.id)
        } else {
            store.expandedHostIDs.insert(host.id)
        }
    }

    private func connect(_ app: HostApp?) {
        guard let request = store.connect(to: host, app: app) else { return }
        openWindow(id: WindowID.session, value: request)
    }
}

/// An app inside an expanded host card.
struct AppRow: View {
    var app: HostApp
    var isRunning: Bool
    var isSelected: Bool
    var select: () -> Void
    var launch: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tileColor.gradient)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: app.isDesktop ? "macwindow" : "app.dashed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

            Text(app.name)
                .frame(maxWidth: .infinity, alignment: .leading)

            detail
                .font(.caption)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(HierarchicalShapeStyle.primary))
        .padding(.vertical, 7)
        .padding(.leading, 70)
        .padding(.trailing, 14)
        .background(isSelected ? Color.accentColor : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: launch)
        .onTapGesture(perform: select)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, select)
        .accessibilityAction(named: "Connect", launch)
    }

    @ViewBuilder
    private var detail: some View {
        if isRunning {
            Text("Running")
        } else if let lastLaunched = app.lastLaunched {
            Text(lastLaunched, format: .relative(presentation: .named))
        }
    }

    private var tileColor: Color {
        app.isDesktop ? .blue : .purple
    }
}
