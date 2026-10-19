import Foundation
import Network
import StarlightCore
import StarlightUI

/// `HostService` on top of the streaming core in client/, through the
/// StarlightCore bridge. The core's calls block, so each runs on a background
/// queue, and cancelling the calling task cancels the core request.
final class CoreHostService: HostService {
    /// Whether to look for computers with Bonjour, from the "mdns" preference.
    private let isDiscoveryEnabled: @Sendable () -> Bool
    private let queue = DispatchQueue(label: "com.moonlight-stream.Starlight.core", attributes: .concurrent)

    init(isDiscoveryEnabled: @escaping @Sendable () -> Bool) {
        self.isDiscoveryEnabled = isDiscoveryEnabled
    }

    func loadSavedHosts() async -> [RemoteHost] {
        (try? await run { _ in SLCore.savedHosts().map { Self.remoteHost($0, status: .unknown) } }) ?? []
    }

    func fetchStatus(for host: RemoteHost) async throws -> HostStatus {
        try await run { cancellation in
            Self.status(of: try SLCore.fetchStatus(ofHost: host.id, address: host.address, cancellation: cancellation))
        }
    }

    func fetchApps(for host: RemoteHost) async throws -> [HostApp] {
        try await run { cancellation in
            try SLCore.fetchApps(ofHost: host.id, cancellation: cancellation)
                .filter { !$0.hidden }
                .map(Self.hostApp)
        }
    }

    func wake(_ host: RemoteHost) async throws {
        try await run { _ in try SLCore.wake(host: host.id) }
    }

    func resolve(address: String) async throws -> RemoteHost {
        try await run { cancellation in
            let resolved = try SLCore.resolve(address: address, cancellation: cancellation)
            return Self.remoteHost(resolved, status: Self.status(of: resolved))
        }
    }

    func pair(_ host: RemoteHost, pin: String) async throws -> RemoteHost {
        try await run { cancellation in
            let paired = try SLCore.pair(address: host.address, pin: pin, cancellation: cancellation)
            return Self.remoteHost(paired, status: Self.status(of: paired))
        }
    }

    func quitApp(on host: RemoteHost) async throws {
        try await run { cancellation in try SLCore.quitApp(onHost: host.id, cancellation: cancellation) }
    }

    func forget(_ host: RemoteHost) async {
        try? await run { _ in try SLCore.forget(host: host.id) }
    }

    /// Computers advertising GameStream (`_nvstream._tcp`) on the local
    /// network, as the core sees them. Saved computers are left out: polling
    /// already covers them.
    func discoverHosts() -> AsyncStream<RemoteHost> {
        guard isDiscoveryEnabled() else {
            // Stay open, like a browser that never finds anything.
            return AsyncStream { _ in }
        }

        return AsyncStream { continuation in
            let discovery = BonjourDiscovery { [weak self] address in
                guard let self else { return }
                Task {
                    guard let host = try? await self.resolve(address: address),
                          host.status == .unpaired else { return }
                    continuation.yield(host)
                }
            }
            discovery.start(on: queue)
            continuation.onTermination = { _ in discovery.cancel() }
        }
    }

    // MARK: - Helpers

    /// Runs a blocking core call on the background queue.
    private func run<T: Sendable>(_ body: @escaping @Sendable (SLCancellation) throws -> T) async throws -> T {
        let cancellation = SLCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        continuation.resume(returning: try body(cancellation))
                    } catch SLCoreError.cancelled {
                        continuation.resume(throwing: CancellationError())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func status(of host: SLHost) -> HostStatus {
        if !host.paired {
            return .unpaired
        }
        return host.runningAppID != 0 ? .busy(appID: host.runningAppID) : .online
    }

    private static func remoteHost(_ host: SLHost, status: HostStatus) -> RemoteHost {
        RemoteHost(id: host.identifier,
                   name: host.name,
                   address: host.address,
                   status: status,
                   apps: host.apps.filter { !$0.hidden }.map(hostApp),
                   canWake: host.canWake)
    }

    private static func hostApp(_ app: SLApp) -> HostApp {
        HostApp(id: app.appID, name: app.name, isHDRSupported: app.hdrSupported)
    }
}

/// Browses for `_nvstream._tcp` and reports each service's IP address once.
private final class BonjourDiscovery: @unchecked Sendable {
    // Only touched on the queue passed to start(on:).
    private let browser = NWBrowser(for: .bonjour(type: "_nvstream._tcp", domain: nil), using: .tcp)
    private var reported: Set<String> = []
    private var connections: [NWConnection] = []
    private let onFound: @Sendable (String) -> Void

    init(onFound: @escaping @Sendable (String) -> Void) {
        self.onFound = onFound
    }

    func start(on queue: DispatchQueue) {
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            for result in results {
                self?.resolve(result.endpoint, on: queue)
            }
        }
        browser.start(queue: queue)
    }

    func cancel() {
        browser.cancel()
        connections.forEach { $0.cancel() }
    }

    /// Bonjour gives a service name; connecting to it is the simplest way to
    /// learn the address the core needs.
    private func resolve(_ endpoint: NWEndpoint, on queue: DispatchQueue) {
        // IPv4, since a link-local IPv6 address is useless without its scope.
        let parameters = NWParameters.tcp
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(to: endpoint, using: parameters)
        connections.append(connection)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                if case .hostPort(let host, _) = connection.currentPath?.remoteEndpoint {
                    self.report(Self.address(of: host))
                }
                connection.cancel()
            case .failed, .cancelled:
                self.connections.removeAll { $0 === connection }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func report(_ address: String) {
        if reported.insert(address).inserted {
            onFound(address)
        }
    }

    private static func address(of host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address):
            return "\(address)"
        case .ipv6(let address):
            // Drop the interface scope, which the core can't parse.
            return "\(address)".components(separatedBy: "%").first ?? "\(address)"
        case .name(let name, _):
            return name
        @unknown default:
            return "\(host)"
        }
    }
}
