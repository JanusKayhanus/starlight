import SwiftUI

/// The contents of a stream window: just the remote screen. Controls live in
/// the View menu (see `StarlightCommands`), so nothing covers the stream.
public struct SessionWindow: View {
    public var request: SessionRequest?

    @Environment(HostStore.self) private var store
    @State private var model: SessionModel?

    public init(request: SessionRequest?) {
        self.request = request
    }

    public var body: some View {
        Group {
            if let model {
                SessionView(model: model)
            } else {
                notConnected
            }
        }
        .onAppear(perform: connect)
        .onDisappear {
            model?.stop()
        }
    }

    /// Shown when the window was restored at launch (the hosts may not be
    /// loaded yet, and reconnecting on its own would be a surprise) or when
    /// the computer is gone.
    private var notConnected: some View {
        let host = request.flatMap { store.host(withID: $0.hostID) }

        return ContentUnavailableView {
            Label(host.map { "Not Connected to \($0.name)" } ?? "Computer Not Available",
                  systemImage: "display")
        } description: {
            Text(host == nil ? "This computer was removed or hasn’t been found yet." : "")
        } actions: {
            Button("Connect", action: connect)
                .buttonStyle(.borderedProminent)
                .disabled(host?.isReachable != true)
        }
        .frame(minWidth: 480, minHeight: 300)
    }

    private func connect() {
        if model == nil, let request {
            model = store.session(for: request)
        }
    }
}

private struct SessionView: View {
    var model: SessionModel

    var body: some View {
        StreamSurface { surface in
            Task { await model.start(on: surface) }
        }
        .overlay {
            switch model.state {
            case .connecting:
                ConnectingOverlay(hostName: model.host.name, appName: model.app.name)
            case .failed(let message):
                FailedOverlay(hostName: model.host.name, message: message)
            case .streaming, .ended:
                EmptyView()
            }
        }
        .background(WindowAccessor { window in model.window = window })
        .navigationTitle(model.host.name)
        .navigationSubtitle(model.app.isDesktop ? "" : model.app.name)
        .focusedSceneValue(\.session, model)
        .frame(minWidth: 640, minHeight: 360)
        .ignoresSafeArea()
    }
}

private struct ConnectingOverlay: View {
    var hostName: String
    var appName: String

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Connecting to \(hostName)…")
                .font(.headline)
            Text(appName)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

private struct FailedOverlay: View {
    var hostName: String
    var message: String

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t Connect to \(hostName)", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Focused session

private struct SessionFocusedValueKey: FocusedValueKey {
    typealias Value = SessionModel
}

extension FocusedValues {
    /// The session in the key window, for the View menu.
    var session: SessionModel? {
        get { self[SessionFocusedValueKey.self] }
        set { self[SessionFocusedValueKey.self] = newValue }
    }
}
