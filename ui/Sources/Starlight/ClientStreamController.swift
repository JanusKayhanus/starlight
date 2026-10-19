import AppKit
import Foundation
import StarlightUI

/// Streams by running the Moonlight client (client/main.cpp) for the chosen
/// host and app. The video plays in the client's own window, so this never
/// draws into the surface it's given; run it with
/// `HostStore.opensStreamWindows` set to false.
@MainActor
final class ClientStreamController: StreamControlling {
    var onTermination: ((StreamTermination) -> Void)?

    private var process: Process?
    private var firstFrame: CheckedContinuation<Void, Error>?
    private var isStreaming = false

    func start(host: RemoteHost, app: HostApp, surface: StreamSurfaceView) async throws {
        try Task.checkCancellation()

        let executable = Self.clientURL
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw LaunchError(message: "The Moonlight client isn’t at \(executable.path).")
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["--host", host.id, "--app", String(app.id)]

        // Pass the client's log through, watch it for the first frame, and
        // keep its last line to explain a failure.
        let output = ClientOutput { [weak self] in
            Task { @MainActor in self?.clientRenderedFirstFrame() }
        }
        let pipe = Pipe()
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            output.append(handle.availableData)
        }
        process.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            let status = process.terminationStatus
            let lastLine = output.lastLine
            Task { @MainActor in self?.clientDidExit(status: status, lastLine: lastLine) }
        }

        try process.run()
        self.process = process

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                firstFrame = continuation
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }

    func stop() {
        let process = self.process
        self.process = nil
        isStreaming = false
        // The client treats SIGTERM like closing its window.
        if let process, process.isRunning {
            process.terminate()
        }
        firstFrame?.resume(throwing: CancellationError())
        firstFrame = nil
    }

    func setScaling(_ mode: ScalingMode) {
        // The client scales to fit its own window.
    }

    func activate() {
        guard let process else { return }
        NSRunningApplication(processIdentifier: process.processIdentifier)?.activate()
    }

    private func clientRenderedFirstFrame() {
        guard process != nil, !isStreaming else { return }
        isStreaming = true
        firstFrame?.resume()
        firstFrame = nil
    }

    private func clientDidExit(status: Int32, lastLine: String?) {
        // Nil once stop() ran, which must not report a termination.
        guard process != nil else { return }
        process = nil

        let message = lastLine ?? "Moonlight exited with status \(status)."
        if let firstFrame {
            // It never started streaming.
            self.firstFrame = nil
            firstFrame.resume(throwing: LaunchError(message: message))
        } else if isStreaming {
            isStreaming = false
            onTermination?(status == 0 ? .endedByHost : .failed(message: message))
        }
    }

    /// The client inside Moonlight.app, `MOONLIGHT_PATH`, or the CMake build
    /// in the repository when running from `swift run`.
    private static var clientURL: URL {
        if let path = ProcessInfo.processInfo.environment["MOONLIGHT_PATH"] {
            return URL(fileURLWithPath: path)
        }
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: "Moonlight"),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        // ui/Sources/Starlight/<this file> → the repository root.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/Moonlight.app/Contents/MacOS/Moonlight")
    }

    struct LaunchError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }
}

/// The client's stderr, read on the pipe's background queue: forwarded to
/// ours, scanned for the first rendered frame, and its last line kept.
private final class ClientOutput: @unchecked Sendable {
    private static let firstFrameMarker = "First frame rendered"

    private let lock = NSLock()
    private var pending = ""
    private var lastNonEmptyLine: String?
    private var sawFirstFrame = false
    private let onFirstFrame: @Sendable () -> Void

    init(onFirstFrame: @escaping @Sendable () -> Void) {
        self.onFirstFrame = onFirstFrame
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        FileHandle.standardError.write(data)

        var reachedFirstFrame = false
        lock.lock()
        pending += String(decoding: data, as: UTF8.self)
        while let newline = pending.firstIndex(of: "\n") {
            let line = String(pending[..<newline])
            pending.removeSubrange(...newline)
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                lastNonEmptyLine = Self.stripLogPrefix(line)
            }
            if !sawFirstFrame && line.contains(Self.firstFrameMarker) {
                sawFirstFrame = true
                reachedFirstFrame = true
            }
        }
        lock.unlock()

        if reachedFirstFrame {
            onFirstFrame()
        }
    }

    var lastLine: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastNonEmptyLine
    }

    /// "2026-10-19 03:02:05.360 Moonlight[48668:1293235] ERROR: message" → "message"
    private static func stripLogPrefix(_ line: String) -> String {
        for level in ["ERROR: ", "WARN: ", "INFO: "] {
            if let range = line.range(of: level) {
                return String(line[range.upperBound...])
            }
        }
        return line
    }
}
