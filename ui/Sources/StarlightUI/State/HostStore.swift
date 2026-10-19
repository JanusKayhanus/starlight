import Foundation
import Observation

/// App-wide state: the list of computers, pairing, and open sessions.
@MainActor
@Observable
public final class HostStore {
    /// How often reachable hosts are polled, matching the Qt build.
    public static let pollInterval: Duration = .seconds(3)

    public private(set) var hosts: [RemoteHost] = []

    /// Presents the Add Computer sheet.
    public var isAddingComputer = false

    /// The pairing in progress, presented as a sheet.
    public private(set) var pairing: PairingSession?

    /// Shown as an alert by whichever window is frontmost.
    public var presentedError: StarlightError?

    /// Expanded host cards in the Computers window.
    public var expandedHostIDs: Set<RemoteHost.ID> = []

    /// The app selected in each expanded host card.
    public var selectedAppIDs: [RemoteHost.ID: HostApp.ID] = [:]

    /// Open stream windows, in the order they were opened.
    public private(set) var sessions: [SessionModel] = []

    private let service: any HostService
    private let makeStreamController: @MainActor () -> any StreamControlling
    private var pollTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var pairingTask: Task<Void, Never>?
    private var hostsBeingWoken: Set<RemoteHost.ID> = []

    public init(service: any HostService,
                makeStreamController: @escaping @MainActor () -> any StreamControlling) {
        self.service = service
        self.makeStreamController = makeStreamController
    }

    // MARK: - Lifecycle

    /// Loads saved hosts and starts polling and discovery. Safe to call more
    /// than once.
    public func start() {
        guard pollTask == nil else { return }

        pollTask = Task { [weak self] in
            guard let self else { return }
            let saved = await self.service.loadSavedHosts()
            self.merge(saved)

            while !Task.isCancelled {
                await self.refreshAll()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }

        discoveryTask = Task { [weak self] in
            guard let stream = self?.service.discoverHosts() else { return }
            for await host in stream {
                self?.merge([host])
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        discoveryTask?.cancel()
        pollTask = nil
        discoveryTask = nil
    }

    // MARK: - Lookup

    public func host(withID id: RemoteHost.ID) -> RemoteHost? {
        hosts.first { $0.id == id }
    }

    public func selectedApp(for host: RemoteHost) -> HostApp? {
        if let id = selectedAppIDs[host.id], let app = host.apps.first(where: { $0.id == id }) {
            return app
        }
        return host.defaultApp
    }

    public func isWaking(_ host: RemoteHost) -> Bool {
        hostsBeingWoken.contains(host.id)
    }

    // MARK: - Actions

    /// Returns the window to open for streaming `app` (or the host's default
    /// app) from `host`, or nil if there's nothing to launch.
    public func sessionRequest(for host: RemoteHost, app: HostApp? = nil) -> SessionRequest? {
        guard host.isPaired, let app = app ?? selectedApp(for: host) else { return nil }
        return SessionRequest(hostID: host.id, appID: app.id)
    }

    public func wake(_ host: RemoteHost) {
        hostsBeingWoken.insert(host.id)
        Task {
            do {
                try await service.wake(host)
            } catch {
                hostsBeingWoken.remove(host.id)
                presentedError = StarlightError(title: "Couldn’t wake “\(host.name)”", error: error)
            }
        }
    }

    public func quitApp(on host: RemoteHost) {
        Task {
            do {
                try await service.quitApp(on: host)
                await refresh(host)
            } catch {
                presentedError = StarlightError(title: "Couldn’t quit the app on “\(host.name)”", error: error)
            }
        }
    }

    public func forget(_ host: RemoteHost) {
        hosts.removeAll { $0.id == host.id }
        expandedHostIDs.remove(host.id)
        selectedAppIDs[host.id] = nil
        Task { await service.forget(host) }
    }

    /// Resolves a typed address and starts pairing with it.
    public func addComputer(address: String) async throws {
        let host = try await service.resolve(address: address)
        merge([host])
        if host.isPaired {
            expandedHostIDs.insert(host.id)
        } else {
            beginPairing(with: host)
        }
    }

    // MARK: - Pairing

    public func beginPairing(with host: RemoteHost) {
        cancelPairing()

        let session = PairingSession(host: host, pin: Self.makePIN())
        pairing = session

        pairingTask = Task {
            do {
                let paired = try await service.pair(host, pin: session.pin)
                guard pairing?.id == session.id else { return }
                pairing = nil
                merge([paired])
                expandedHostIDs.insert(paired.id)
                await refresh(paired)
            } catch is CancellationError {
                // The user cancelled; the sheet is already gone.
            } catch {
                guard pairing?.id == session.id else { return }
                pairing = nil
                presentedError = StarlightError(title: "Couldn’t pair with “\(host.name)”", error: error)
            }
        }
    }

    public func cancelPairing() {
        pairingTask?.cancel()
        pairingTask = nil
        pairing = nil
    }

    private static func makePIN() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }

    // MARK: - Sessions

    /// The model for a stream window, created on first use.
    public func session(for request: SessionRequest) -> SessionModel? {
        if let existing = sessions.first(where: { $0.request == request }) {
            return existing
        }
        guard let host = host(withID: request.hostID),
              let app = host.apps.first(where: { $0.id == request.appID }) else {
            return nil
        }

        let model = SessionModel(request: request, host: host, app: app,
                                 controller: makeStreamController())
        model.onEnded = { [weak self, weak model] in
            guard let self, let model else { return }
            self.sessions.removeAll { $0 === model }
            Task { await self.refresh(host) }
        }
        sessions.append(model)
        return model
    }

    // MARK: - Polling

    private func refreshAll() async {
        let service = self.service
        let snapshot = hosts

        let results = await withTaskGroup(of: (RemoteHost.ID, HostStatus?).self) { group in
            for host in snapshot {
                group.addTask {
                    (host.id, try? await service.fetchStatus(for: host))
                }
            }
            var results: [(RemoteHost.ID, HostStatus?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        for (id, status) in results {
            apply(status ?? .offline, toHostWithID: id)
        }
    }

    private func refresh(_ host: RemoteHost) async {
        let status = try? await service.fetchStatus(for: host)
        apply(status ?? .offline, toHostWithID: host.id)
    }

    private func apply(_ status: HostStatus, toHostWithID id: RemoteHost.ID) {
        guard let index = hosts.firstIndex(where: { $0.id == id }) else { return }

        let wasReachable = hosts[index].isReachable
        hosts[index].status = status
        if status != .offline {
            hostsBeingWoken.remove(id)
        }

        // Fetch apps when a paired host comes online.
        let host = hosts[index]
        if host.isReachable, host.isPaired, !wasReachable || host.apps.isEmpty {
            Task { await loadApps(for: host) }
        }
    }

    private func loadApps(for host: RemoteHost) async {
        guard let apps = try? await service.fetchApps(for: host),
              let index = hosts.firstIndex(where: { $0.id == host.id }) else { return }
        hosts[index].apps = apps
    }

    /// Adds new hosts and updates known ones, keeping the existing order.
    private func merge(_ incoming: [RemoteHost]) {
        for host in incoming {
            if let index = hosts.firstIndex(where: { $0.id == host.id || $0.address == host.address }) {
                var merged = host
                if merged.apps.isEmpty {
                    merged.apps = hosts[index].apps
                }
                if merged.status == .unknown {
                    merged.status = hosts[index].status
                }
                hosts[index] = merged
            } else {
                hosts.append(host)
            }
        }
    }
}

/// A pairing in progress: the host and the PIN to enter on it.
public struct PairingSession: Identifiable, Equatable {
    public let id = UUID()
    public let host: RemoteHost
    public let pin: String
}
