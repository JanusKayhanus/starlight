import SwiftUI

/// The main window: a compact list of computers.
public struct ComputersView: View {
    @Environment(HostStore.self) private var store

    public init() {}

    public var body: some View {
        @Bindable var store = store

        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.hosts) { host in
                    HostCard(host: host)
                }
            }
            .padding(10)
        }
        .overlay {
            if store.hosts.isEmpty {
                ContentUnavailableView {
                    Label("No Computers", systemImage: "display")
                } description: {
                    Text("Computers running Sunshine on this network appear here automatically.")
                } actions: {
                    Button("Add Computer…") { store.isAddingComputer = true }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 320)
        .navigationTitle("Starlight")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.isAddingComputer = true
                } label: {
                    Label("Add Computer", systemImage: "plus")
                }
                .help("Add a computer by name or address")

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings")
            }
        }
        .sheet(isPresented: $store.isAddingComputer) {
            AddComputerSheet()
        }
        .sheet(item: Binding(get: { store.pairing }, set: { if $0 == nil { store.cancelPairing() } })) { pairing in
            PairingSheet(pairing: pairing)
        }
        .errorAlert()
    }
}

/// Asks for a computer's name or address.
struct AddComputerSheet: View {
    @Environment(HostStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var address = ""
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Computer")
                .font(.headline)
            Text("Enter the name or IP address of a computer running Sunshine.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Name or address", text: $address)
                .textFieldStyle(.roundedBorder)
                .disabled(isResolving)
                .onSubmit(add)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if isResolving {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isResolving)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func add() {
        guard !isResolving else { return }
        isResolving = true
        errorMessage = nil

        Task {
            do {
                try await store.addComputer(address: address)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isResolving = false
        }
    }
}

/// Shows the PIN to enter on the host while pairing.
struct PairingSheet: View {
    var pairing: PairingSession

    @Environment(HostStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            Text("Pair with “\(pairing.host.name)”")
                .font(.headline)

            Text("Enter this PIN in Sunshine on \(pairing.host.name).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(pairing.pin)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .tracking(6)
                .textSelection(.enabled)
                .accessibilityLabel("PIN \(pairing.pin.map(String.init).joined(separator: " "))")

            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for \(pairing.host.name)…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.cancelPairing()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 290)
    }
}

extension View {
    /// Presents `HostStore.presentedError` as an alert.
    func errorAlert() -> some View {
        modifier(ErrorAlertModifier())
    }
}

private struct ErrorAlertModifier: ViewModifier {
    @Environment(HostStore.self) private var store

    func body(content: Content) -> some View {
        content.alert(
            store.presentedError?.title ?? "",
            isPresented: Binding(get: { store.presentedError != nil },
                                 set: { if !$0 { store.presentedError = nil } }),
            presenting: store.presentedError
        ) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.message)
        }
    }
}
