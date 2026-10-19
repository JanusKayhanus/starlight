import Foundation

/// Everything the UI needs to know about hosts, without streaming.
///
/// The real implementation will wrap the C++ core in `client/` through an
/// Objective-C++ bridge:
///
/// | Method            | Core today                                             |
/// |-------------------|--------------------------------------------------------|
/// | `loadSavedHosts`  | `settings.cpp`, generalized to read every `hosts.N.*` slot |
/// | `fetchStatus`     | `fetchServerInfo()` in `serverinfo.cpp`                |
/// | `fetchApps`       | Not implemented yet: needs an HTTPS `/applist` request |
/// | `wake`            | Not implemented yet: needs the MAC from serverinfo     |
/// | `resolve`         | `fetchServerInfo()` over HTTP for a typed address      |
/// | `pair`            | `pairHost()` in `pairing.cpp`, then `savePairedHost()` |
/// | `quitApp`         | `/cancel`, as in `Session::quitHostApp()`              |
/// | `discoverHosts`   | Not implemented yet: `NWBrowser` for `_nvstream._tcp`  |
///
/// The core's HTTP calls block, so the bridge should run them off the main
/// thread. `pair` must stop when its task is cancelled, which needs a cancel
/// hook in `http.cpp` because the first pairing stage waits indefinitely.
public protocol HostService: Sendable {
    /// Hosts this client has paired with before.
    func loadSavedHosts() async -> [RemoteHost]

    /// Polls the host and returns its current status.
    func fetchStatus(for host: RemoteHost) async throws -> HostStatus

    /// The apps the host publishes.
    func fetchApps(for host: RemoteHost) async throws -> [HostApp]

    /// Sends a Wake-on-LAN packet. Returns once it has been sent; the host
    /// shows up as online through the normal status polling.
    func wake(_ host: RemoteHost) async throws

    /// Looks up a host the user typed in by name or address. The result is
    /// typically `.unpaired`.
    func resolve(address: String) async throws -> RemoteHost

    /// Pairs with `host` using `pin`, which the UI generates and shows so the
    /// user can enter it on the host. Returns the host as now paired.
    /// Must throw `CancellationError` promptly when the task is cancelled.
    func pair(_ host: RemoteHost, pin: String) async throws -> RemoteHost

    /// Quits whatever app the host is running.
    func quitApp(on host: RemoteHost) async throws

    /// Removes a saved host and its pinned certificate.
    func forget(_ host: RemoteHost) async

    /// Hosts found on the local network. The stream stays open until the
    /// consuming task is cancelled.
    func discoverHosts() -> AsyncStream<RemoteHost>
}
