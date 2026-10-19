import Foundation

/// A `HostService` with canned hosts and simulated delays, for running the UI
/// without the streaming core.
public actor MockHostService: HostService {
    private static let desktopAppID = 881448767

    private var hosts: [RemoteHost]
    private let discoverable: [RemoteHost]

    public init() {
        let now = Date()
        let desktop = HostApp(id: Self.desktopAppID, name: "Desktop", isHDRSupported: true,
                              lastLaunched: now.addingTimeInterval(-25 * 60))

        hosts = [
            RemoteHost(id: "mock-studio", name: "Studio PC", address: "192.168.1.42",
                 status: .busy(appID: Self.desktopAppID),
                 apps: [
                    desktop,
                    HostApp(id: 2, name: "Steam Big Picture",
                            lastLaunched: now.addingTimeInterval(-6 * 24 * 3600))
                 ],
                 canWake: true),
            RemoteHost(id: "mock-work", name: "Work Laptop", address: "work-laptop.local",
                 status: .online, apps: [HostApp(id: Self.desktopAppID, name: "Desktop")]),
            RemoteHost(id: "mock-media", name: "Media Server", address: "192.168.1.20",
                 status: .online, apps: [HostApp(id: Self.desktopAppID, name: "Desktop")],
                 canWake: true),
            RemoteHost(id: "mock-office", name: "Office Tower", address: "10.0.4.7",
                 status: .offline, apps: [HostApp(id: Self.desktopAppID, name: "Desktop")],
                 canWake: true)
        ]

        discoverable = [
            RemoteHost(id: "mock-living-room", name: "Living Room PC", address: "192.168.1.61",
                 status: .unpaired)
        ]
    }

    public func loadSavedHosts() async -> [RemoteHost] {
        try? await Task.sleep(for: .milliseconds(150))
        // Report everything as unknown first, like a fresh launch would.
        return hosts.map { host in
            var host = host
            host.status = .unknown
            return host
        }
    }

    public func fetchStatus(for host: RemoteHost) async throws -> HostStatus {
        try await Task.sleep(for: .milliseconds(Int.random(in: 100...400)))
        if let saved = hosts.first(where: { $0.id == host.id }) {
            return saved.status
        }
        return discoverable.first(where: { $0.id == host.id })?.status ?? .offline
    }

    public func fetchApps(for host: RemoteHost) async throws -> [HostApp] {
        try await Task.sleep(for: .milliseconds(200))
        return hosts.first(where: { $0.id == host.id })?.apps ?? []
    }

    public func wake(_ host: RemoteHost) async throws {
        try await Task.sleep(for: .milliseconds(300))

        // Pretend the host finishes booting a few seconds later.
        let id = host.id
        Task {
            try? await Task.sleep(for: .seconds(4))
            self.setStatus(.online, forHostWithID: id)
        }
    }

    public func resolve(address: String) async throws -> RemoteHost {
        try await Task.sleep(for: .milliseconds(800))

        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else {
            throw MockError.unreachable(address)
        }
        if let existing = (hosts + discoverable).first(where: { $0.address == trimmed }) {
            return existing
        }

        let looksLikeIP = trimmed.allSatisfy { $0.isNumber || $0 == "." }
        return RemoteHost(id: "mock-\(trimmed)",
                    name: looksLikeIP ? "New Computer" : trimmed,
                    address: trimmed,
                    status: .unpaired)
    }

    public func pair(_ host: RemoteHost, pin: String) async throws -> RemoteHost {
        // Give the user time to "type" the PIN on the host. Task.sleep throws
        // CancellationError if the user cancels.
        try await Task.sleep(for: .seconds(5))

        var paired = host
        paired.status = .online
        paired.apps = [HostApp(id: Self.desktopAppID, name: "Desktop")]
        paired.canWake = true

        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = paired
        } else {
            hosts.append(paired)
        }
        return paired
    }

    public func quitApp(on host: RemoteHost) async throws {
        try await Task.sleep(for: .milliseconds(600))
        setStatus(.online, forHostWithID: host.id)
    }

    public func forget(_ host: RemoteHost) async {
        hosts.removeAll { $0.id == host.id }
    }

    public nonisolated func discoverHosts() -> AsyncStream<RemoteHost> {
        AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .seconds(2))
                for host in await self.unpairedDiscoverableHosts() {
                    continuation.yield(host)
                }
                // Keep the stream open like a real browser would.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Simulates the host starting or stopping an app, for SessionModel.
    func setStatus(_ status: HostStatus, forHostWithID id: RemoteHost.ID) {
        if let index = hosts.firstIndex(where: { $0.id == id }) {
            hosts[index].status = status
        }
    }

    private func unpairedDiscoverableHosts() -> [RemoteHost] {
        discoverable.filter { candidate in !hosts.contains { $0.id == candidate.id } }
    }

    enum MockError: LocalizedError {
        case unreachable(String)

        var errorDescription: String? {
            switch self {
            case .unreachable(let address):
                return "“\(address)” didn’t respond. Check that Sunshine is running and the computer is on this network."
            }
        }
    }
}
