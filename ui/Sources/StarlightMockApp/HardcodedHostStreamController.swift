import AppKit
import Foundation
import QuartzCore
import StarlightUI

/// Streams the first computer in the list for real by launching the Qt-free
/// client, which connects to its hardcoded host (see `loadMoonlightSettings()`
/// in client/settings.cpp) in its own window. Every other computer stays mocked.
///
/// The stream window stays open while the client runs: closing it quits the
/// client, and the window closes when the client exits.
@MainActor
final class HardcodedHostStreamController: StreamControlling {
    /// The first card in the Computers window (see `MockHostService`).
    static let hostID = "mock-studio"

    var onTermination: ((StreamTermination) -> Void)? {
        didSet { mock.onTermination = onTermination }
    }

    private let mock: MockStreamController
    private var process: Process?
    private weak var messageLayer: CATextLayer?

    init(hostService: MockHostService) {
        mock = MockStreamController(hostService: hostService)
    }

    func start(host: RemoteHost, app: HostApp, surface: StreamSurfaceView) async throws {
        guard host.id == Self.hostID else {
            return try await mock.start(host: host, app: app, surface: surface)
        }
        try Task.checkCancellation()

        let executable = Self.executableURL
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw LaunchError.missingClient(executable.path)
        }

        let process = Process()
        process.executableURL = executable

        // Pass the client's output through to this terminal, and keep its last
        // line to explain a failed launch.
        let errors = OutputTail()
        let pipe = Pipe()
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            FileHandle.standardError.write(data)
            errors.append(data)
        }

        process.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            let status = process.terminationStatus
            Task { @MainActor in
                self?.clientDidExit(status: status, lastError: errors.lastLine)
            }
        }

        try process.run()
        self.process = process
        showMessage("Streaming in the Moonlight window\nClose this window to disconnect", on: surface)
    }

    func stop() {
        guard let process else {
            mock.stop()
            return
        }
        self.process = nil
        messageLayer?.removeFromSuperlayer()
        if process.isRunning {
            process.terminate()
        }
    }

    func setScaling(_ mode: ScalingMode) {}

    private func clientDidExit(status: Int32, lastError: String?) {
        // Nil once stop() has run, which must not report a termination.
        guard process != nil else { return }
        process = nil
        messageLayer?.removeFromSuperlayer()

        if status == 0 {
            onTermination?(.endedByHost)
        } else {
            onTermination?(.failed(message: lastError ?? "Moonlight exited with status \(status)."))
        }
    }

    private func showMessage(_ message: String, on surface: StreamSurfaceView) {
        guard let layer = surface.layer else { return }
        let text = CATextLayer()
        text.string = message
        text.fontSize = 15
        text.alignmentMode = .center
        text.foregroundColor = NSColor.white.withAlphaComponent(0.7).cgColor
        text.contentsScale = surface.window?.backingScaleFactor ?? 2
        text.bounds = CGRect(x: 0, y: 0, width: 460, height: 44)
        text.position = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
        text.autoresizingMask = [.layerMinXMargin, .layerMaxXMargin, .layerMinYMargin, .layerMaxYMargin]
        layer.addSublayer(text)
        messageLayer = text
    }

    /// `MOONLIGHT_PATH`, or the client built into `build/` at the top of the repo.
    private static var executableURL: URL {
        if let path = ProcessInfo.processInfo.environment["MOONLIGHT_PATH"] {
            return URL(fileURLWithPath: path)
        }
        // ui/Sources/StarlightMockApp/<this file> → the repository root.
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repository.appendingPathComponent("build/Moonlight.app/Contents/MacOS/Moonlight")
    }

    enum LaunchError: LocalizedError {
        case missingClient(String)

        var errorDescription: String? {
            switch self {
            case .missingClient(let path):
                return "The Moonlight client isn’t built at \(path). Build it with “cmake --build build”, or set MOONLIGHT_PATH."
            }
        }
    }
}

/// The last line a process wrote, collected from its pipe's background queue.
private final class OutputTail: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""

    func append(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        buffer = String((buffer + text).suffix(4096))
        lock.unlock()
    }

    var lastLine: String? {
        lock.lock()
        defer { lock.unlock() }
        return buffer
            .split(whereSeparator: \.isNewline)
            .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init)
    }
}
