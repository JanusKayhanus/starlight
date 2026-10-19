import Foundation

/// A computer running Sunshine (or GeForce Experience) that Starlight can
/// stream from.
///
/// This mirrors the subset of the core's `HostConfig` (client/settings.h) that
/// the UI needs. The real `HostService` is expected to build these from the
/// saved host slots and the host's `/serverinfo` and `/applist` responses.
public struct RemoteHost: Identifiable, Hashable, Sendable {
    /// Stable identifier. Use the host's UUID once known; an unpaired host
    /// found by address or Bonjour can fall back to its address.
    public var id: String
    public var name: String
    public var address: String
    public var status: HostStatus
    public var apps: [HostApp]
    /// True when a MAC address is known, so a Wake-on-LAN packet can be sent.
    public var canWake: Bool

    public init(id: String,
                name: String,
                address: String,
                status: HostStatus = .unknown,
                apps: [HostApp] = [],
                canWake: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.status = status
        self.apps = apps
        self.canWake = canWake
    }

    /// The app the host is currently streaming, if any.
    public var runningApp: HostApp? {
        guard case .busy(let appID) = status else { return nil }
        return apps.first { $0.id == appID }
    }

    /// The app to launch when the user just clicks Connect: the running app
    /// (so the session resumes), then Desktop, then whatever comes first.
    public var defaultApp: HostApp? {
        runningApp ?? apps.first { $0.isDesktop } ?? apps.first
    }

    public var isPaired: Bool {
        status != .unpaired
    }

    public var isReachable: Bool {
        switch status {
        case .online, .busy, .unpaired:
            return true
        case .offline, .unknown:
            return false
        }
    }
}

public enum HostStatus: Hashable, Sendable {
    /// Not polled yet.
    case unknown
    /// Reachable and paired, not streaming anything.
    case online
    /// Reachable and paired, currently running the app with this ID.
    case busy(appID: Int)
    /// Not responding to `/serverinfo`.
    case offline
    /// Reachable, but this client isn't paired with it.
    case unpaired
}

/// An app published by the host (`/applist`), such as "Desktop".
public struct HostApp: Identifiable, Hashable, Sendable {
    /// Sunshine's app ID, as sent in the `/launch` request.
    public var id: Int
    public var name: String
    public var isHDRSupported: Bool
    /// When this client last launched the app. The host doesn't report this,
    /// so the real service has to record it locally.
    public var lastLaunched: Date?

    public init(id: Int, name: String, isHDRSupported: Bool = false, lastLaunched: Date? = nil) {
        self.id = id
        self.name = name
        self.isHDRSupported = isHDRSupported
        self.lastLaunched = lastLaunched
    }

    public var isDesktop: Bool {
        name.caseInsensitiveCompare("Desktop") == .orderedSame
    }
}

/// Identifies a stream window. Codable so SwiftUI can restore the window.
public struct SessionRequest: Codable, Hashable, Sendable {
    public var hostID: RemoteHost.ID
    public var appID: HostApp.ID

    public init(hostID: RemoteHost.ID, appID: HostApp.ID) {
        self.hostID = hostID
        self.appID = appID
    }
}

/// An error worth showing to the user as an alert.
public struct StarlightError: Error, Identifiable, Sendable {
    public let id = UUID()
    public var title: String
    public var message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public init(title: String, error: Error) {
        self.title = title
        self.message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
