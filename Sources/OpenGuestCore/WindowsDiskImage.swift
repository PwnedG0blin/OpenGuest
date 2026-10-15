#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

public enum WindowsDiskImage {
    public static func info(qemuImg: String, disk: URL) throws -> Int64 {
        let result = try CommandCapture.run(CommandSpec(executable: qemuImg, arguments: ["info", "-f", "qcow2", "--output=json", disk.path]), timeout: 30)
        guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
        return try WindowsDisk.virtualBytes(from: result.data)
    }
    /// Off the UI thread. The VM session already holds the same lock during guest preparation.
    public static func prepare(qemuImg: String, storage: GuestStorage, capacityGiB: Int, acquireLock: Bool = true) throws -> Int64 {
        let capacity = try WindowsDisk.capacityGiB(String(capacityGiB))
        let root = try storage.prepareWindowsFolder()
        let fm = FileManager.default
        var fd: Int32 = -1
        if acquireLock {
            fd = open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR, 0o600)
            guard fd >= 0 else { throw StorageMigration.failure("Windows-Festplatte konnte nicht gesperrt werden.") }
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
                close(fd)
                throw StorageMigration.failure("Windows läuft bereits in einer anderen OpenGuest-Instanz. Zum Ändern vollständig herunterfahren.")
            }
        }
        defer { if fd >= 0 { flock(fd, LOCK_UN); close(fd) } }
        let disk = root.appendingPathComponent("windows.qcow2")
        if let attributes = try? fm.attributesOfItem(atPath: disk.path) {
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  disk.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else {
                throw StorageMigration.failure("Windows-Festplatte ist keine reguläre Datei im gewählten Ordner.")
            }
            let current = try info(qemuImg: qemuImg, disk: disk)
            if try WindowsDisk.requiresGrowth(currentBytes: current, requestedGiB: capacity) {
                try storage.validate()
                let result = try CommandCapture.run(CommandSpec(executable: qemuImg,
                    arguments: ["resize", "-f", "qcow2", disk.path, "\(capacity)G"]), timeout: 60)
                guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
            }
        } else {
            let temporary = root.appendingPathComponent("disk-\(UUID().uuidString).qcow2")
            defer { try? fm.removeItem(at: temporary) }
            let result = try CommandCapture.run(CommandSpec(executable: qemuImg,
                arguments: ["create", "-f", "qcow2", temporary.path, "\(capacity)G"]), timeout: 30)
            guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
            try storage.validate()
            try fm.moveItem(at: temporary, to: disk)
        }
        let actual = try info(qemuImg: qemuImg, disk: disk)
        guard actual == Int64(capacity) * 1_073_741_824 else {
            throw StorageMigration.failure("Die Festplattengröße konnte nach der Änderung nicht bestätigt werden.")
        }
        return actual
    }
}
