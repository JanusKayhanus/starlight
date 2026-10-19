import AppKit
import Foundation
import StarlightUI

/// Streams the first computer in the list for real by launching the Qt-free
/// client, which connects to its hardcoded host (see `loadMoonlightSettings()`
/// in client/settings.cpp) in its own window. Every other computer stays mocked.
@MainActor
final class HardcodedHostLauncher {
    /// The first card in the Computers window (see `MockHostService`).
    static let hostID = "mock-studio"

    /// Called with the client's last error line when it exits unsuccessfully.
    var onFailure: ((RemoteHost, String) -> Void)?

    private var process: Process?

    /// Launches the client for the hardcoded host. Returns false for every
    /// other host, so it opens the mock stream window instead.
    func launch(_ host: RemoteHost) -> Bool {
        guard host.id == Self.hostID else { return false }

        // One stream at a time: bring the running client forward instead.
        if let process, process.isRunning {
            NSRunningApplication(processIdentifier: process.processIdentifier)?.activate()
            return true
        }

        let executable = Self.executableURL
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            onFailure?(host, "The Moonlight client isn’t built at \(executable.path). Build it with “cmake --build build”, or set MOONLIGHT_PATH.")
            return true
        }

        let process = Process()
        process.executableURL = executable

        // Pass the client's output through, and keep its last line to explain
        // a failed launch.
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
                self?.clientDidExit(host, status: status, lastError: errors.lastLine)
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            onFailure?(host, error.localizedDescription)
        }
        return true
    }

    private func clientDidExit(_ host: RemoteHost, status: Int32, lastError: String?) {
        process = nil
        if status != 0 {
            onFailure?(host, lastError ?? "Moonlight exited with status \(status).")
        }
    }

    /// `MOONLIGHT_PATH`, the client next to this executable in Moonlight.app,
    /// or (under `swift run`) the client built into `build/` at the top of the repo.
    private static var executableURL: URL {
        if let path = ProcessInfo.processInfo.environment["MOONLIGHT_PATH"] {
            return URL(fileURLWithPath: path)
        }
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: "Moonlight"),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        // ui/Sources/StarlightMockApp/<this file> → the repository root.
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repository.appendingPathComponent("build/Moonlight.app/Contents/MacOS/Moonlight")
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
