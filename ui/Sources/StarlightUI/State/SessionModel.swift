import AppKit
import Observation

/// State for one stream window.
@MainActor
@Observable
public final class SessionModel {
    public enum State: Equatable {
        case connecting
        case streaming
        case failed(message: String)
        case ended
    }

    public let request: SessionRequest
    public let host: RemoteHost
    public let app: HostApp
    public private(set) var state: State = .connecting

    public private(set) var scaling: ScalingMode = .fit

    /// The window showing this session, for moving it between screens.
    @ObservationIgnored weak var window: NSWindow?

    /// Called once the session is over, however it ended.
    @ObservationIgnored var onEnded: (() -> Void)?

    private let controller: any StreamControlling
    private var hasStarted = false

    init(request: SessionRequest, host: RemoteHost, app: HostApp, controller: any StreamControlling) {
        self.request = request
        self.host = host
        self.app = app
        self.controller = controller

        controller.onTermination = { [weak self] termination in
            guard let self else { return }
            switch termination {
            case .endedByHost:
                self.state = .ended
                self.window?.close()
            case .failed(let message):
                self.state = .failed(message: message)
            }
            self.onEnded?()
        }
    }

    func start(on surface: StreamSurfaceView) async {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            try await controller.start(host: host, app: app, surface: surface)
            if state == .connecting {
                state = .streaming
            }
        } catch is CancellationError {
            // The window was closed while connecting.
        } catch {
            state = .failed(message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Ends the stream. Called when the window closes.
    public func stop() {
        guard state != .ended else { return }
        controller.stop()
        state = .ended
        onEnded?()
    }

    /// Ends the stream and closes its window.
    public func disconnect() {
        stop()
        window?.close()
    }

    public func setScaling(_ mode: ScalingMode) {
        scaling = mode
        controller.setScaling(mode)
    }

    public func bringToFront() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Moves the stream window to `screen`, keeping its size where it fits.
    /// The core's equivalent for full-screen streams is `Session::cycleDisplay()`.
    public func move(to screen: NSScreen) {
        guard let window else { return }

        guard !window.styleMask.contains(.fullScreen) else {
            // Leave full screen first, then move once the animation is done.
            window.toggleFullScreen(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.move(to: screen)
                self?.window?.toggleFullScreen(nil)
            }
            return
        }

        let visible = screen.visibleFrame
        var frame = window.frame
        frame.size.width = min(frame.width, visible.width)
        frame.size.height = min(frame.height, visible.height)
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(frame, display: true, animate: true)
    }
}
