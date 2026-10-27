import Darwin
import Foundation

public struct NetworkCommandResult: Sendable {
    public var status: Int32
    public var stdout: String
    public var stderr: String
    public var timedOut: Bool
    public var launchError: String?

    public init(
        status: Int32,
        stdout: String,
        stderr: String,
        timedOut: Bool,
        launchError: String? = nil
    ) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
        self.timedOut = timedOut
        self.launchError = launchError
    }

    public var succeeded: Bool {
        launchError == nil && !timedOut && status == 0
    }
}

public enum NetworkCommand {
    public static func run(
        executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 6,
        maxOutputBytes: Int = 160_000
    ) async -> NetworkCommandResult {
        await Task.detached(priority: .utility) {
            execute(
                executable: executable,
                arguments: arguments,
                timeout: timeout,
                maxOutputBytes: maxOutputBytes
            )
        }.value
    }

    private static func execute(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        maxOutputBytes: Int
    ) -> NetworkCommandResult {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("builders-protect-net-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return NetworkCommandResult(
                status: -1,
                stdout: "",
                stderr: "",
                timedOut: false,
                launchError: error.localizedDescription
            )
        }
        defer { try? fileManager.removeItem(at: directory) }

        let outURL = directory.appendingPathComponent("stdout")
        let errURL = directory.appendingPathComponent("stderr")
        guard fileManager.createFile(atPath: outURL.path, contents: nil),
              fileManager.createFile(atPath: errURL.path, contents: nil),
              let outHandle = try? FileHandle(forWritingTo: outURL),
              let errHandle = try? FileHandle(forWritingTo: errURL) else {
            return NetworkCommandResult(
                status: -1,
                stdout: "",
                stderr: "",
                timedOut: false,
                launchError: "Não consegui preparar a captura de saída."
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outHandle
        process.standardError = errHandle
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["LC_ALL": "C", "LANG": "C"]
        ) { _, new in new }

        let flag = TimeoutFlag()
        do {
            try process.run()
        } catch {
            try? outHandle.close()
            try? errHandle.close()
            return NetworkCommandResult(
                status: -1,
                stdout: "",
                stderr: "",
                timedOut: false,
                launchError: error.localizedDescription
            )
        }

        let watchdog = DispatchWorkItem {
            guard process.isRunning else { return }
            flag.mark()
            process.terminate()
            let pid = process.processIdentifier
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                if process.isRunning {
                    kill(pid, SIGKILL)
                }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout,
            execute: watchdog
        )

        process.waitUntilExit()
        watchdog.cancel()
        try? outHandle.close()
        try? errHandle.close()

        let stdout = readLimited(outURL, maxBytes: maxOutputBytes)
        let stderr = readLimited(errURL, maxBytes: 32_000)
        return NetworkCommandResult(
            status: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            timedOut: flag.value
        )
    }

    private static func readLimited(_ url: URL, maxBytes: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: maxBytes)) ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func mark() {
        lock.lock()
        stored = true
        lock.unlock()
    }
}
