import Foundation

public enum ExchangeFolder {
    public static let windowsAddress = #"\\10.0.2.2\Austausch"#
    public static let smbAddress = "smb://10.0.2.2/Austausch"
    public static let androidDirectory = "/sdcard/Download/Stratovo-Austausch"

    @discardableResult
    public static func prepare(storage: GuestStorage) throws -> URL {
        try storage.validate()
        let url = storage.url.appendingPathComponent("Austausch", isDirectory: true)
        guard url.standardizedFileURL == url.resolvingSymlinksInPath().standardizedFileURL else {
            throw StorageMigration.failure("Austausch darf keine Verknüpfung sein.")
        }
        let fm = FileManager.default
        if let type = try? fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType,
           type != .typeDirectory {
            throw StorageMigration.failure("Austausch ist bereits vorhanden, aber kein Ordner.")
        }
        try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return url
    }

    public static func newAndroidImport(storage: GuestStorage) throws -> URL {
        let parent = try prepare(storage: storage).appendingPathComponent("Android", isDirectory: true)
        guard parent.standardizedFileURL == parent.resolvingSymlinksInPath().standardizedFileURL else {
            throw StorageMigration.failure("Android-Austausch darf keine Verknüpfung sein.")
        }
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        let child = parent.appendingPathComponent("Import-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        return child
    }
}
