import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct CommandResult {
    public let status: Int32
    public let data: Data
    public var output: String { String(decoding: data, as: UTF8.self) }
}

public enum CommandCapture {
    // Call off the UI thread. A regular file avoids stdout/stderr pipe deadlocks.
    public static func run(_ command: CommandSpec, timeout: TimeInterval = 12, outputLimit: Int = 512 * 1024) throws -> CommandResult {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openguest-probe-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw GuestError.missingFile(url.path) }
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { _, new in new }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var timedOut = false
        while process.isRunning {
            if ProcessInfo.processInfo.systemUptime >= deadline {
                timedOut = true
                process.terminate()
                let grace = ProcessInfo.processInfo.systemUptime + 1
                while process.isRunning && ProcessInfo.processInfo.systemUptime < grace { Thread.sleep(forTimeInterval: 0.02) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        process.waitUntilExit()
        if timedOut { throw GuestError.timedOut }
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        let data = try reader.read(upToCount: outputLimit) ?? Data()
        return CommandResult(status: process.terminationStatus, data: data)
    }
}
