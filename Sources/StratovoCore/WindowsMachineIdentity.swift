import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Stable virtual hardware, independent of the Mac's own device identifiers.
public struct WindowsMachineIdentity: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable { case legacy, unique }
    public let version: Int
    public let mode: Mode
    public let uuid: String?
    public let serial: String
    public let mac: String?

    public static let legacy = WindowsMachineIdentity(version: 1, mode: .legacy, uuid: nil, serial: "OpenGuestWindows", mac: nil)
    public static func generate() -> Self {
        let id = UUID().uuidString.lowercased()
        let hex = id.replacingOccurrences(of: "-", with: "")
        let suffix = String(hex.suffix(12))
        var octets = stride(from: 0, to: 12, by: 2).map { i -> UInt8 in
            let start = suffix.index(suffix.startIndex, offsetBy: i)
            return UInt8(suffix[start..<suffix.index(start, offsetBy: 2)], radix: 16)!
        }
        octets[0] = (octets[0] & 0xfc) | 0x02 // locally administered unicast
        return Self(version: 1, mode: .unique, uuid: id, serial: "PK" + String(hex.prefix(18)),
                    mac: octets.map { String(format: "%02x", $0) }.joined(separator: ":"))
    }
    public func validate() throws {
        guard version == 1 else { throw StorageMigration.failure("Unbekannte Version der Windows-Gerätekennung.") }
        if mode == .legacy {
            guard self == .legacy else { throw StorageMigration.failure("Bisherige Windows-Gerätekennung ist beschädigt.") }
        } else {
            guard let uuid, let parsed = UUID(uuidString: uuid), parsed.uuidString.lowercased() == uuid.lowercased(),
                  uuid.replacingOccurrences(of: "-", with: "").contains(where: { $0 != "0" }),
                  serial.range(of: #"^PK[0-9a-f]{18}$"#, options: .regularExpression) != nil,
                  let mac, mac.range(of: #"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$"#, options: .regularExpression) != nil,
                  let first = UInt8(mac.prefix(2), radix: 16), first & 3 == 2 else {
                throw StorageMigration.failure("Windows-Gerätekennung ist beschädigt. Sie wird nicht automatisch ersetzt.")
            }
        }
    }
    public var summary: String {
        mode == .legacy ? "Bisherige Standardkennung · OpenGuestWindows · keine eigene VM-UUID" : "Eigene Gerätekennung · UUID \(uuid ?? "") · Seriennummer \(serial) · MAC \(mac ?? "")"
    }
}

public enum WindowsIdentityStore {
    private struct Change: Codable {
        let version: Int
        let before: WindowsMachineIdentity
        let after: WindowsMachineIdentity
    }
    private static func directory(_ root: URL) -> URL { root.appendingPathComponent("Machine", isDirectory: true) }
    private static func file(_ root: URL) -> URL { directory(root).appendingPathComponent("identity.json") }
    private static func receipt(_ root: URL) -> URL { directory(root).appendingPathComponent("identity-change.json") }
    private static func attributes(_ url: URL) throws -> [FileAttributeKey: Any]? {
        do { return try FileManager.default.attributesOfItem(atPath: url.path) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code) { return nil }
    }
    private static func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        guard try attributes(url)?[.type] as? FileAttributeType == .typeRegular else {
            throw StorageMigration.failure("Gerätekennung fehlt oder ist keine reguläre Datei: \(url.path)")
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    private static func write<T: Encodable>(_ value: T, at url: URL) throws {
        if let attr = try attributes(url), attr[.type] as? FileAttributeType != .typeRegular {
            throw StorageMigration.failure("Kennungsdatei darf keine Verknüpfung sein: \(url.path)")
        }
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public static func load(root: URL) throws -> WindowsMachineIdentity? {
        guard let attr = try attributes(directory(root)) else { return nil }
        guard attr[.type] as? FileAttributeType == .typeDirectory else {
            throw StorageMigration.failure("Windows-Kennungsordner ist keine regulärer Ordner.")
        }
        let identity = try read(WindowsMachineIdentity.self, at: file(root))
        try identity.validate()
        return identity
    }
    /// Called with the VM session lock held, before creating the first disk.
    public static func prepare(root: URL) throws -> WindowsMachineIdentity {
        if let saved = try load(root: root) { return saved }
        let existing = try attributes(root.appendingPathComponent("windows.qcow2")) != nil
        let value: WindowsMachineIdentity = existing ? .legacy : .generate()
        try FileManager.default.createDirectory(at: directory(root), withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try write(value, at: file(root))
        return value
    }
    private static func change(root: URL) throws -> Change? {
        guard try attributes(receipt(root)) != nil else { return nil }
        let value = try read(Change.self, at: receipt(root))
        try value.before.validate(); try value.after.validate()
        guard value.version == 1, value.before == .legacy, value.after.mode == .unique else {
            throw StorageMigration.failure("Sicherung der ursprünglichen Gerätekennung ist ungültig.")
        }
        return value
    }
    public static func canRestore(root: URL) throws -> Bool {
        guard let current = try load(root: root), let saved = try change(root: root) else { return false }
        return current == saved.after
    }
    /// Never changes disk contents, firmware variables, TPM state, or the Mac's identity.
    public static func useUnique(storage: GuestStorage, restore: Bool = false) throws -> WindowsMachineIdentity {
        let root = try storage.prepareWindowsFolder()
        let fd = open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw StorageMigration.failure("Windows-Gerätekennung konnte nicht gesperrt werden.") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw StorageMigration.failure("Windows läuft bereits. Für die Gerätekennung vollständig herunterfahren.")
        }
        defer { flock(fd, LOCK_UN); close(fd) }
        guard try attributes(root.appendingPathComponent("windows.qcow2"))?[.type] as? FileAttributeType == .typeRegular else {
            throw StorageMigration.failure("Noch keine Windows-Festplatte vorhanden. Neue VMs erhalten ihre eigene Kennung beim ersten Start.")
        }
        let current = try prepare(root: root)
        let saved = try change(root: root)
        let next: WindowsMachineIdentity
        if restore {
            guard let saved, current == saved.after else { throw StorageMigration.failure("Keine passende ursprüngliche Gerätekennung zum Wiederherstellen.") }
            next = saved.before
        } else {
            if current.mode == .unique { return current }
            if let saved { next = saved.after }
            else {
                next = .generate()
                try write(Change(version: 1, before: current, after: next), at: receipt(root))
            }
        }
        try storage.validate()
        try write(next, at: file(root))
        guard try load(root: root) == next else { throw StorageMigration.failure("Gerätekennung konnte nicht bestätigt werden.") }
        return next
    }
}
