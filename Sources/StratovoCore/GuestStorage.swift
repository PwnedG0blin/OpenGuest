import CryptoKit
import Foundation

/// Large guest data lives here. The small pointer file remains in Application Support.
// The legacy OpenGuest configuration path is kept for update compatibility.
public struct GuestStorage: Codable, Equatable {
    public let root: String
    public let id: String
    public var mediaSources: [String] = []
    public var url: URL { URL(fileURLWithPath: root, isDirectory: true) }
    public var sdk: URL { url.appendingPathComponent("Android/sdk") }
    public var avd: URL { url.appendingPathComponent("Android/avd") }
    public var runtime: URL { url.appendingPathComponent("Runtime") }
    public var windows: URL { url.appendingPathComponent("Windows") }
    public var logs: URL { url.appendingPathComponent("Logs") }
    public var environment: [String: String] {
        ["ANDROID_HOME": sdk.path, "ANDROID_SDK_ROOT": sdk.path, "ANDROID_AVD_HOME": avd.path]
    }
    public static var pointer: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenGuest/storage.json")
    }
    public static func load(from pointer: URL = Self.pointer) -> GuestStorage? {
        guard let bytes = try? Data(contentsOf: pointer) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: bytes)
    }
    public func validate() throws {
        let marker = url.appendingPathComponent(".openguest-storage-id")
        guard (try? String(contentsOf: marker, encoding: .utf8)) == id,
              FileManager.default.isWritableFile(atPath: root) else {
            throw StorageMigration.failure("Speicherort nicht erreichbar: \(root). SSD anschließen und erneut prüfen. Es wird kein Ersatzordner auf der internen Platte angelegt.")
        }
    }
    public func save(to pointer: URL = Self.pointer) throws {
        try validate()
        try FileManager.default.createDirectory(at: pointer.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: pointer, options: .atomic)
    }
    public var freeBytes: Int64? {
        guard let values = try? FileManager.default.attributesOfFileSystem(forPath: root),
              let size = values[.systemFreeSize] as? NSNumber else { return nil }
        return size.int64Value
    }
    public var windowsFolderReady: Bool {
        guard (try? validate()) != nil,
              windows.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/") else { return false }
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: windows.path, isDirectory: &directory) && directory.boolValue &&
            FileManager.default.isWritableFile(atPath: windows.path)
    }
    @discardableResult
    public func prepareWindowsFolder() throws -> URL {
        try validate()
        guard windows.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/") else {
            throw StorageMigration.failure("Windows-Ordner verweist außerhalb des gewählten Datenordners.")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: windows, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let probe = windows.appendingPathComponent(".write-test-\(UUID().uuidString)")
        try Data([0]).write(to: probe, options: .withoutOverwriting)
        defer { try? fm.removeItem(at: probe) }
        try validate()
        return windows
    }
}

public enum StorageMigration {
    private struct Receipt: Codable {
        let key: String
        let fingerprint: String
    }
    private struct Entry {
        let key: String
        let source: URL
        let destination: URL
        var backup: URL { URL(fileURLWithPath: source.path + ".OpenGuest-intern", isDirectory: true) }
    }
    private static func entries(_ storage: GuestStorage, home: URL, support: URL) -> [Entry] {
        [Entry(key: "sdk", source: home.appendingPathComponent("Library/Android/sdk"), destination: storage.sdk),
         Entry(key: "avd", source: home.appendingPathComponent(".android/avd"), destination: storage.avd),
         Entry(key: "runtime", source: support.appendingPathComponent("Runtime"), destination: storage.runtime),
         Entry(key: "windows", source: support.appendingPathComponent("Windows11ProArm"), destination: storage.windows),
         Entry(key: "logs", source: support.appendingPathComponent("Logs"), destination: storage.logs)] + storage.mediaSources.map {
            Entry(key: "iso:" + $0, source: URL(fileURLWithPath: $0),
                  destination: storage.url.appendingPathComponent("Installationsmedien").appendingPathComponent(URL(fileURLWithPath: $0).lastPathComponent))
         }
    }
    public static func failure(_ text: String) -> NSError {
        NSError(domain: "OpenGuest.Storage", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
    private static func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
    private static func link(_ url: URL) -> String? {
        try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)
    }
    private static func resolved(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }
    private static func receipts(_ storage: GuestStorage) -> URL { storage.url.appendingPathComponent(".migration.json") }
    private static func readReceipts(_ storage: GuestStorage) throws -> [Receipt] {
        let file = receipts(storage)
        if !exists(file) { return [] }
        return try JSONDecoder().decode([Receipt].self, from: Data(contentsOf: file))
    }
    private static func writeReceipts(_ values: [Receipt], _ storage: GuestStorage) throws {
        try JSONEncoder().encode(values).write(to: receipts(storage), options: .atomic)
    }

    /// Copies and checks every byte before renaming originals. No originals are deleted here.
    /// Default locations are deliberately explicit; unrelated SDKs, projects and downloads are untouched.
    public static func prepare(root: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser,
                               support: URL = GuestStorage.pointer.deletingLastPathComponent(),
                               mediaSources: [String] = [], progress: @escaping (String) -> Void = { _ in }) throws -> GuestStorage {
        let fm = FileManager.default
        let root = root.standardizedFileURL
        guard root.path != "/", root.path != home.path, !root.path.hasPrefix(support.path + "/"), root.path != support.path else {
            throw failure("Bitte einen eigenen Stratovo-Datenordner außerhalb der bisherigen Daten auswählen.")
        }
        // Reject overlapping locations and symlink parents before creating anything.
        let media = Array(Set(mediaSources)).sorted()
        try validateMedia(media, home: home)
        let prototype = GuestStorage(root: root.path, id: "", mediaSources: media)
        let plan = entries(prototype, home: home, support: support)
        let canonicalRoot = resolved(root)
        for item in plan {
            let old = resolved(item.source)
            if canonicalRoot == old || canonicalRoot.hasPrefix(old + "/") || old.hasPrefix(canonicalRoot + "/") {
                // Existing links to this exact data folder are handled below on resume.
                if link(item.source) == nil || old != resolved(item.destination) {
                    throw failure("Datenquelle und Ziel überlappen: \(item.source.path)")
                }
            }
        }
        let marker = root.appendingPathComponent(".openguest-storage-id")
        let identifier: String
        if exists(marker) {
            identifier = try String(contentsOf: marker, encoding: .utf8)
            guard UUID(uuidString: identifier) != nil else { throw failure("Ungültige Speicherort-Markierung.") }
        } else {
            // User selected an existing, mounted parent in the folder picker.
            guard fm.isWritableFile(atPath: root.deletingLastPathComponent().path) else {
                throw failure("Ziel-Laufwerk fehlt oder ist nicht beschreibbar.")
            }
            try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            identifier = UUID().uuidString
            try identifier.write(to: marker, atomically: true, encoding: .utf8)
        }
        let storage = GuestStorage(root: root.path, id: identifier, mediaSources: media)
        try storage.validate()
        var journal = try readReceipts(storage)
        for item in entries(storage, home: home, support: support) {
            try storage.validate()
            progress("Übernehme und prüfe \(item.key) …")
            if link(item.destination) != nil { throw failure("Ziel darf keine Verknüpfung sein: \(item.destination.path)") }
            if let _ = link(item.source) {
                guard resolved(item.source) == resolved(item.destination) else {
                    throw failure("\(item.source.path) verweist bereits auf einen anderen Speicherort. Keine Änderung vorgenommen.")
                }
                if exists(item.backup), !journal.contains(where: { $0.key == item.key }) {
                    let hash = try fingerprint(item.backup)
                    try verifyCopy(item.backup, destination: item.destination)
                    journal.append(Receipt(key: item.key, fingerprint: hash))
                    try writeReceipts(journal, storage)
                }
                continue
            }
            if exists(item.backup) {
                // Recovery after termination between rename and link creation.
                guard !exists(item.source), let record = journal.first(where: { $0.key == item.key }),
                      try fingerprint(item.backup) == record.fingerprint else {
                    throw failure("Sicherung existiert bereits; bitte zuerst prüfen: \(item.backup.path). Nichts wird überschrieben.")
                }
                try verifyCopy(item.backup, destination: item.destination)
                try fm.createSymbolicLink(atPath: item.source.path, withDestinationPath: item.destination.path)
                continue
            }
            if exists(item.source) {
                let sourceType = try fm.attributesOfItem(atPath: item.source.path)[.type] as? FileAttributeType
                guard sourceType == .typeDirectory || (item.key.hasPrefix("iso:") && sourceType == .typeRegular) else {
                    throw failure("Datenquelle hat einen unerwarteten Typ: \(item.source.path)")
                }
                let before = try fingerprint(item.source)
                try mergeCopy(item.source, to: item.destination, validate: storage.validate)
                try verifyCopy(item.source, destination: item.destination)
                let hash = try fingerprint(item.source)
                guard before == hash else { throw failure("Quelldaten wurden während des Kopierens verändert: \(item.source.path). Bitte Android Studio und Einrichtungsskripte beenden und erneut versuchen. Original bleibt erhalten.") }
                journal.removeAll { $0.key == item.key }
                journal.append(Receipt(key: item.key, fingerprint: hash))
                try writeReceipts(journal, storage) // durable before rename
                try fm.moveItem(at: item.source, to: item.backup)
                do { try fm.createSymbolicLink(atPath: item.source.path, withDestinationPath: item.destination.path) }
                catch { try? fm.moveItem(at: item.backup, to: item.source); throw error }
            } else {
                if item.key.hasPrefix("iso:") { continue }
                try fm.createDirectory(at: item.destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try fm.createDirectory(at: item.source.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.createSymbolicLink(atPath: item.source.path, withDestinationPath: item.destination.path)
            }
        }
        return storage
    }

    /// Only exact legacy backup paths from our receipt are eligible, never arbitrary user paths.
    public static func backupPaths(_ storage: GuestStorage, home: URL = FileManager.default.homeDirectoryForCurrentUser,
                                   support: URL = GuestStorage.pointer.deletingLastPathComponent()) throws -> [String] {
        try storage.validate()
        try validateMedia(storage.mediaSources, home: home)
        let journal = try readReceipts(storage)
        return entries(storage, home: home, support: support).filter { item in
            journal.contains { $0.key == item.key } && exists(item.backup)
        }.map { $0.backup.path }
    }
    public static func cleanup(_ storage: GuestStorage, home: URL = FileManager.default.homeDirectoryForCurrentUser,
                               support: URL = GuestStorage.pointer.deletingLastPathComponent(),
                               progress: @escaping (String) -> Void = { _ in }) throws {
        try storage.validate()
        try validateMedia(storage.mediaSources, home: home)
        let journal = try readReceipts(storage)
        let plan = entries(storage, home: home, support: support).filter { item in
            exists(item.backup) && journal.contains { $0.key == item.key }
        }
        // Check every candidate before removing any. Guests may have changed the destination
        // after first boot; the immutable original backup must still match the saved receipt.
        for item in plan {
            progress("Prüfe interne Sicherung \(item.key) …")
            guard link(item.backup) == nil, link(item.destination) == nil,
                  link(item.source) != nil, resolved(item.source) == resolved(item.destination),
                  exists(item.destination), try containsCriticalFiles(item.backup, destination: item.destination), let record = journal.first(where: { $0.key == item.key }),
                  try fingerprint(item.backup) == record.fingerprint else {
                throw failure("Interne Sicherung wurde verändert oder das Ziel fehlt: \(item.backup.path). Bereinigung abgebrochen.")
            }
        }
        for item in plan {
            try storage.validate()
            progress("Entferne geprüfte interne Kopie \(item.key) …")
            try FileManager.default.removeItem(at: item.backup)
        }
    }

    private static func validateMedia(_ paths: [String], home: URL) throws {
        let downloads = resolved(home.appendingPathComponent("Downloads"))
        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.path == path, url.pathExtension.lowercased() == "iso",
                  resolved(url.deletingLastPathComponent()).hasPrefix(downloads + "/") || resolved(url.deletingLastPathComponent()) == downloads else {
                throw failure("Automatischer ISO-Umzug ist nur für ausgewählte ISO-Dateien aus Downloads vorgesehen: \(path)")
            }
        }
    }

    private static func containsCriticalFiles(_ source: URL, destination: URL) throws -> Bool {
        let fm = FileManager.default
        let type = try fm.attributesOfItem(atPath: source.path)[.type] as? FileAttributeType
        guard type == .typeDirectory else {
            guard exists(destination) else { return false }
            return try fm.attributesOfItem(atPath: destination.path)[.type] as? FileAttributeType == type
        }
        guard exists(destination), link(destination) == nil else { return false }
        let children = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        if !children.isEmpty {
            let current = try fm.contentsOfDirectory(atPath: destination.path)
            if current.isEmpty { return false }
        }
        for child in children {
            // Guest disk data and ISO images must still exist. Runtime logs and emulator
            // lock/cache files can legitimately disappear after a guest has booted.
            if ["img", "qcow2", "iso", "fd"].contains(child.pathExtension.lowercased()) {
                if !exists(destination.appendingPathComponent(child.lastPathComponent)) { return false }
            }
        }
        return true
    }

    private static func mergeCopy(_ source: URL, to destination: URL, validate: () throws -> Void) throws {
        try validate()
        let fm = FileManager.default
        let type = try fm.attributesOfItem(atPath: source.path)[.type] as? FileAttributeType
        if type == .typeDirectory {
            if exists(destination) {
                guard link(destination) == nil,
                      try fm.attributesOfItem(atPath: destination.path)[.type] as? FileAttributeType == .typeDirectory else {
                    throw failure("Zielkonflikt: \(destination.path)")
                }
            } else {
                try fm.createDirectory(at: destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            }
            for child in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) {
                try mergeCopy(child, to: destination.appendingPathComponent(child.lastPathComponent), validate: validate)
            }
        } else if exists(destination) {
            guard try fingerprint(source) == fingerprint(destination) else { throw failure("Datei existiert mit anderem Inhalt: \(destination.path). Nichts überschrieben.") }
        } else {
            guard type == .typeRegular || type == .typeSymbolicLink else { throw failure("Nicht unterstützte Datei: \(source.path)") }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: destination)
        }
    }

    /// Verify every source entry, not equality of directory listings. macOS can add
    /// AppleDouble / Finder metadata on another filesystem; extra target entries are
    /// preserved. Missing, changed or incorrectly typed source payload still aborts.
    static func verifyCopy(_ source: URL, destination: URL) throws {
        let fm = FileManager.default
        let sourceType = try fm.attributesOfItem(atPath: source.path)[.type] as? FileAttributeType
        guard exists(destination),
              try fm.attributesOfItem(atPath: destination.path)[.type] as? FileAttributeType == sourceType else {
            throw failure("Kopierprüfung: Datei fehlt oder hat einen anderen Typ. Quelle: \(source.path) · Ziel: \(destination.path). Original bleibt erhalten.")
        }
        if sourceType == .typeDirectory {
            for child in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                try verifyCopy(child, destination: destination.appendingPathComponent(child.lastPathComponent))
            }
        } else {
            guard try fingerprint(source) == fingerprint(destination) else {
                throw failure("Kopierprüfung: Dateiinhalt unterscheidet sich. Quelle: \(source.path) · Ziel: \(destination.path). Original bleibt erhalten.")
            }
        }
    }

    private static func fingerprint(_ url: URL) throws -> String {
        let fm = FileManager.default
        let type = try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        var hash = SHA256()
        if type == .typeDirectory {
            hash.update(data: Data("directory\0".utf8))
            for child in try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                hash.update(data: try JSONEncoder().encode([child.lastPathComponent, fingerprint(child)]))
            }
        } else if type == .typeSymbolicLink {
            hash.update(data: Data(("link\0" + (try fm.destinationOfSymbolicLink(atPath: url.path))).utf8))
        } else if type == .typeRegular {
            hash.update(data: Data("file\0".utf8))
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        } else { throw failure("Dateityp kann nicht geprüft werden: \(url.path)") }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
