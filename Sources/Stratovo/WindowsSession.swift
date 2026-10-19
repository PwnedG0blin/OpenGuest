import Darwin
import Foundation
import StratovoCore

@MainActor
final class WindowsSession {
    struct Files {
        let variables: String
        let disk: String
        let socket: String
        let displaySocket: String
        let qmpSocket: String
        let proISO: String?
        let identity: WindowsMachineIdentity
    }
    private var lockFD: Int32 = -1
    private var tpm: Process?
    private var tpmOutput: FileHandle?
    private var socketDirectory: URL?
    private var answerDirectory: URL?

    static var root: URL {
        GuestStorage.load()?.windows ?? GuestStorage.pointer.deletingLastPathComponent().appendingPathComponent("Windows11ProArm")
    }

    func prepare(qemuImg: String, swtpm: String, variablesTemplate: String, capacityGiB: Int, selectPro: Bool,
                 localAccount: WindowsEdition.LocalAccount?) async throws -> Files {
        guard let storage = GuestStorage.load() else { throw failure(L10n.text("Speicherort fehlt.")) }
        try storage.validate()
        let fm = FileManager.default
        let root = try storage.prepareWindowsFolder()
        let fd = Darwin.open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw failure(L10n.text("Die Windows-VM konnte nicht gesperrt werden.")) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw failure(L10n.text("Diese Windows-VM wird bereits von einer anderen Stratovo-Instanz verwendet."))
        }
        lockFD = fd

        let identity = try WindowsIdentityStore.prepare(root: root)
        let variables = root.appendingPathComponent("uefi-vars.fd")
        if !fm.fileExists(atPath: variables.path) { try fm.copyItem(atPath: variablesTemplate, toPath: variables.path) }
        let disk = root.appendingPathComponent("windows.qcow2")
        _ = try await Task.detached {
            try WindowsDiskImage.prepare(qemuImg: qemuImg, storage: storage, capacityGiB: capacityGiB, acquireLock: false)
        }.value

        var editionISO: String?
        if selectPro || localAccount != nil {
            let privateDirectory = root.appendingPathComponent("Setup-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: privateDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            answerDirectory = privateDirectory
            let iso = privateDirectory.appendingPathComponent("Setup.iso")
            let contents = privateDirectory.appendingPathComponent("Content", isDirectory: true)
            try fm.createDirectory(at: contents, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            try WindowsEdition.setupXML(selectPro: selectPro, localAccount: localAccount)
                .write(to: contents.appendingPathComponent("autounattend.xml"), atomically: true, encoding: .utf8)
                let result = try await Task.detached {
                    try CommandCapture.run(CommandSpec(executable: "/usr/bin/hdiutil", arguments: [
                        "makehybrid", "-o", iso.path, "-iso", "-joliet", "-default-volume-name", "OGPRO", contents.path
                    ]), timeout: 30)
                }.value
                guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
            editionISO = iso.path
        }

        let state = root.appendingPathComponent("TPM", isDirectory: true)
        try fm.createDirectory(at: state, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        // Short socket paths avoid the macOS Unix-domain socket path length limit.
        let socketDir = URL(fileURLWithPath: "/tmp/og-\(UUID().uuidString.prefix(12))", isDirectory: true)
        try fm.createDirectory(at: socketDir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        socketDirectory = socketDir
        let socket = socketDir.appendingPathComponent("tpm.sock")
        let tpmLog = root.appendingPathComponent("tpm-last.log")
        guard fm.createFile(atPath: tpmLog.path, contents: nil) else { throw failure(L10n.text("TPM-Protokoll konnte nicht erstellt werden.")) }
        let handle = try FileHandle(forWritingTo: tpmLog)
        tpmOutput = handle
        let child = Process()
        child.executableURL = URL(fileURLWithPath: swtpm)
        child.arguments = ["socket", "--tpm2", "--tpmstate", "dir=\(state.path)",
                           "--ctrl", "type=unixio,path=\(socket.path),terminate", "--flags", "not-need-init"]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = handle
        child.standardError = handle
        try child.run()
        tpm = child
        for _ in 0..<100 {
            guard child.isRunning else {
                let detail = (try? String(contentsOf: tpmLog, encoding: .utf8)) ?? ""
                throw failure("TPM konnte nicht starten. \(detail)")
            }
            if fm.fileExists(atPath: socket.path) {
                return Files(variables: variables.path, disk: disk.path, socket: socket.path,
                             displaySocket: socketDir.appendingPathComponent("display.sock").path,
                             qmpSocket: socketDir.appendingPathComponent("qmp.sock").path, proISO: editionISO, identity: identity)
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw failure(L10n.text("TPM-Start hat das Zeitlimit überschritten."))
    }

    func stop() async {
        if let tpm {
            await Task.detached {
                if tpm.isRunning { tpm.terminate() }
                let deadline = ProcessInfo.processInfo.systemUptime + 2
                while tpm.isRunning && ProcessInfo.processInfo.systemUptime < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
                if tpm.isRunning { kill(tpm.processIdentifier, SIGKILL) }
                tpm.waitUntilExit()
            }.value
        }
        tpm = nil
        try? tpmOutput?.close()
        tpmOutput = nil
        if let socketDirectory { try? FileManager.default.removeItem(at: socketDirectory) }
        socketDirectory = nil
        if let answerDirectory { try? FileManager.default.removeItem(at: answerDirectory) }
        answerDirectory = nil
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "OpenGuest.Windows", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
