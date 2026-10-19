import AppKit
import QuartzCore

/// A `StreamControlling` that "connects" after a short delay and draws a
/// placeholder into the surface instead of video.
@MainActor
public final class MockStreamController: StreamControlling {
    public var onTermination: ((StreamTermination) -> Void)?

    private let hostService: MockHostService?
    private var hostID: RemoteHost.ID?
    private weak var placeholder: CATextLayer?

    /// Pass the mock host service so the host shows the app as running while
    /// the mock stream is open.
    public init(hostService: MockHostService? = nil) {
        self.hostService = hostService
    }

    public func start(host: RemoteHost, app: HostApp, surface: StreamSurfaceView) async throws {
        try await Task.sleep(for: .seconds(1.5))

        hostID = host.id
        if let hostService {
            await hostService.setStatus(.busy(appID: app.id), forHostWithID: host.id)
        }

        guard let layer = surface.layer else { return }
        layer.backgroundColor = NSColor(calibratedRed: 0.17, green: 0.29, blue: 0.43, alpha: 1).cgColor

        let text = CATextLayer()
        text.string = "\(app.name) on \(host.name)\nMock stream: the renderer isn’t connected yet"
        text.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        text.fontSize = 15
        text.alignmentMode = .center
        text.foregroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
        text.contentsScale = surface.window?.backingScaleFactor ?? 2
        text.bounds = CGRect(x: 0, y: 0, width: 460, height: 44)
        text.position = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
        text.autoresizingMask = [.layerMinXMargin, .layerMaxXMargin, .layerMinYMargin, .layerMaxYMargin]
        layer.addSublayer(text)
        placeholder = text
    }

    public func stop() {
        placeholder?.removeFromSuperlayer()
        placeholder = nil

        if let hostService, let hostID {
            Task { await hostService.setStatus(.online, forHostWithID: hostID) }
        }
        hostID = nil
    }

    public func setScaling(_ mode: ScalingMode) {
        // Nothing to scale in the mock.
    }
}
