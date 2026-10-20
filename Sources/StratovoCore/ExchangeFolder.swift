import Foundation

public enum ExchangeFolder {
    public static let windowsAddress = #"\\10.0.2.2\Austausch"#
    public static let smbAddress = "smb://10.0.2.2/Austausch"
    public static let androidDirectory = "/sdcard/Download/Stratovo-Austausch"

    @discardableResult
    public static func prepare(storage: GuestStorage) throws -> URL {
        try storage.validate()
        let url = storage.url.appendingPathComponent("Austausch", isDirectory: true)
        try prepareDirectory(url)
        return url
    }

    private static func prepareDirectory(_ url: URL) throws {
        guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().standardizedFileURL.path else {
            throw StorageMigration.failure("Austausch darf keine Verknüpfung sein.")
        }
        let fm = FileManager.default
        if let type = try? fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType {
            guard type == .typeDirectory else {
                throw StorageMigration.failure("Austausch ist bereits vorhanden, aber kein Ordner.")
            }
            return
        }
        try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    }

    public static func newAndroidImport(storage: GuestStorage) throws -> URL {
        let parent = try prepare(storage: storage).appendingPathComponent("Android", isDirectory: true)
        try prepareDirectory(parent)
        let child = parent.appendingPathComponent("Import-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
        return child
    }
}
