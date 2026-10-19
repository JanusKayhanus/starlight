import AppKit

/// How the remote screen is fitted into the stream window.
public enum ScalingMode: String, CaseIterable, Identifiable, Sendable {
    case fit
    case actualSize

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fit: return "Scale to Fit"
        case .actualSize: return "Actual Size"
        }
    }
}

/// Why a stream ended without the user closing the window.
public enum StreamTermination: Sendable {
    /// The host ended the session, for example because the app quit.
    case endedByHost
    /// The connection failed.
    case failed(message: String)
}

/// Drives one stream into a `StreamSurfaceView`.
///
/// The real implementation will wrap the core's `Session` (client/streaming).
/// Today `Session` creates its own SDL window and runs its own event loop on
/// the main thread, so connecting this needs `Session` to render into the
/// surface's `CAMetalLayer` instead of `SDL_Metal_CreateView()`, and to take
/// its input from the surface view rather than from SDL window events.
///
/// The core supports one session at a time.
@MainActor
public protocol StreamControlling: AnyObject {
    /// Called when the stream ends on its own. Not called after `stop()`.
    var onTermination: ((StreamTermination) -> Void)? { get set }

    /// Launches (or resumes) `app` on `host` and starts presenting into
    /// `surface`. Returns once the first frame is on screen. Must throw
    /// `CancellationError` promptly when its task is cancelled, which happens
    /// when the window is closed while connecting.
    func start(host: RemoteHost, app: HostApp, surface: StreamSurfaceView) async throws

    /// Ends the stream. Safe to call more than once.
    func stop()

    func setScaling(_ mode: ScalingMode)
}
