import Foundation

public enum AndroidSystem: Int, CaseIterable, Identifiable {
    case android16 = 16, android17 = 17
    public var id: Int { rawValue }
    public var title: String { "Android \(rawValue) mit Google Play" }
    public var platform: String { self == .android16 ? "android-36" : "android-37.0" }
    public var package: String { "system-images;\(platform);google_apis_playstore;arm64-v8a" }
    public var profile: String { "Pixelkoje_Android\(rawValue)_64GB" }
    public static func detect(_ config: [String: String]) -> Self? {
        let path = config["image.sysdir.1", default: ""].split(separator: "/").map(String.init)
        return allCases.first { path.contains($0.platform) && path.contains("google_apis_playstore") && path.contains("arm64-v8a") }
    }
}

/// Plans only local Android entries; no Windows, runtime, media or internal paths.
public struct AndroidCleanupPlan: Equatable {
    public let keeping: String
    public let paths: [String]
}

public enum AndroidMaintenance {
    private static func checked(_ url: URL, root: URL) throws {
        let fm = FileManager.default
        guard url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/"),
              url.resolvingSymlinksInPath().path == root.resolvingSymlinksInPath().appendingPathComponent(String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))).path,
              (try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) != .typeSymbolicLink else {
            throw StorageMigration.failure("Bereinigung abgebrochen: Verknüpfung oder fremder Pfad: \(url.path)")
        }
    }
    public static func plan(storage: GuestStorage, keeping name: String) throws -> AndroidCleanupPlan {
        try storage.validate()
        let fm = FileManager.default
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
            throw StorageMigration.failure("Ungültiger Android-Profilname.")
        }
        let root = storage.url.standardizedFileURL
        let keep = storage.avd.appendingPathComponent(name + ".avd")
        try checked(keep, root: root)
        let config = RuntimeDiscovery.parseINI(try String(contentsOf: keep.appendingPathComponent("config.ini"), encoding: .utf8))
        guard AndroidSystem.detect(config) == .android16,
              fm.isReadableFile(atPath: keep.appendingPathComponent("userdata-qemu.img").path) else {
            throw StorageMigration.failure("Zuerst das funktionierende Android-16-Profil auswählen. Seine Daten müssen vorhanden sein.")
        }
        let keepImage = config["image.sysdir.1", default: ""]
        let image = keepImage.hasPrefix("/") ? URL(fileURLWithPath: keepImage) : storage.sdk.appendingPathComponent(keepImage)
        try checked(image.standardizedFileURL, root: root)
        guard fm.isReadableFile(atPath: image.appendingPathComponent("system.img").path) else {
            throw StorageMigration.failure("Android-16-Systemabbild fehlt. Nichts wird gelöscht.")
        }
        let locator = storage.avd.appendingPathComponent(name + ".ini")
        if fm.fileExists(atPath: locator.path) {
            try checked(locator, root: root)
            let values = RuntimeDiscovery.parseINI(try String(contentsOf: locator, encoding: .utf8))
            if let path = values["path"], URL(fileURLWithPath: path).standardizedFileURL != keep.standardizedFileURL {
                throw StorageMigration.failure("Das gewählte Profil verweist auf einen anderen Ordner. Bitte manuell prüfen.")
            }
        }
        var paths: [String] = []
        let entries = try fm.contentsOfDirectory(at: storage.avd, includingPropertiesForKeys: nil)
        for entry in entries where ["avd", "ini"].contains(entry.pathExtension) {
            try checked(entry, root: root)
            if entry.deletingPathExtension().lastPathComponent == name { continue }
            if entry.pathExtension == "ini" {
                let values = RuntimeDiscovery.parseINI(try String(contentsOf: entry, encoding: .utf8))
                // A locator outside this managed directory may belong to Android Studio.
                if let path = values["path"], URL(fileURLWithPath: path).standardizedFileURL.deletingLastPathComponent() != storage.avd.standardizedFileURL {
                    throw StorageMigration.failure("Ein Android-Profil verweist außerhalb des Datenordners: \(entry.lastPathComponent). Bitte manuell prüfen.")
                }
            } else {
                // Never treat an arbitrary folder ending in .avd as a disposable VM.
                guard fm.isReadableFile(atPath: entry.appendingPathComponent("config.ini").path) else {
                    throw StorageMigration.failure("Unbekannter Profilordner: \(entry.lastPathComponent). Nichts wird gelöscht.")
                }
            }
            paths.append(entry.path)
        }
        let images = storage.sdk.appendingPathComponent("system-images")
        // Only known older/newer Android platform folders; retain the complete Android-16 platform.
        if fm.fileExists(atPath: images.path) {
            try checked(images, root: root)
            let retainedPlatform = image.standardizedFileURL.pathComponents.dropFirst(images.standardizedFileURL.pathComponents.count).first
            var sharedPlatforms: Set<String> = []
            let otherRoot = fm.homeDirectoryForCurrentUser.appendingPathComponent(".android/avd")
            if fm.fileExists(atPath: otherRoot.path), otherRoot.resolvingSymlinksInPath() != storage.avd.resolvingSymlinksInPath() {
                for entry in try fm.contentsOfDirectory(at: otherRoot, includingPropertiesForKeys: nil) where entry.pathExtension == "ini" {
                    let values = RuntimeDiscovery.parseINI(try String(contentsOf: entry, encoding: .utf8))
                    let directory = values["path"].map { URL(fileURLWithPath: $0) }
                        ?? otherRoot.appendingPathComponent(entry.deletingPathExtension().lastPathComponent + ".avd")
                    guard let text = try? String(contentsOf: directory.appendingPathComponent("config.ini"), encoding: .utf8) else {
                        throw StorageMigration.failure("Ein weiteres Android-Profil kann nicht geprüft werden. Systemabbilder werden nicht entfernt.")
                    }
                    let source = RuntimeDiscovery.parseINI(text)["image.sysdir.1", default: ""]
                    for part in source.split(separator: "/") where part.hasPrefix("android-") { sharedPlatforms.insert(String(part)) }
                }
            }
            for entry in try fm.contentsOfDirectory(at: images, includingPropertiesForKeys: nil) {
                guard entry.lastPathComponent.range(of: #"^android-[0-9]+([.][0-9]+)?(-ext[0-9]+)?$"#, options: .regularExpression) != nil,
                      entry.lastPathComponent != retainedPlatform, !sharedPlatforms.contains(entry.lastPathComponent) else { continue }
                try checked(entry, root: root)
                paths.append(entry.path)
            }
        }
        let backups = root.appendingPathComponent("Backups")
        if fm.fileExists(atPath: backups.path) {
            try checked(backups, root: root)
            for entry in try fm.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil) where entry.lastPathComponent.hasPrefix("Android-vor-Vergroesserung.") {
                try checked(entry, root: root)
                let children = try fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil)
                // Only the exact Android-15 backup layout created by our migration instructions.
                guard children.allSatisfy({ ["OpenGuest_GooglePlay.avd", "dateisystem-probe.img", ".DS_Store"].contains($0.lastPathComponent) }),
                      let old = children.first(where: { $0.lastPathComponent == "OpenGuest_GooglePlay.avd" }),
                      let oldConfig = try? String(contentsOf: old.appendingPathComponent("config.ini"), encoding: .utf8),
                      RuntimeDiscovery.parseINI(oldConfig)["image.sysdir.1", default: ""].contains("android-35/") else { continue }
                paths.append(entry.path)
            }
        }
        return AndroidCleanupPlan(keeping: name, paths: paths.sorted())
    }
    public static func cleanup(storage: GuestStorage, expected: AndroidCleanupPlan) throws {
        let actual = try plan(storage: storage, keeping: expected.keeping)
        guard actual == expected else { throw StorageMigration.failure("Die Bereinigungsliste hat sich geändert. Bitte erneut prüfen.") }
        for path in actual.paths {
            try storage.validate()
            try checked(URL(fileURLWithPath: path), root: storage.url.standardizedFileURL)
        }
        for path in actual.paths {
            try storage.validate()
            try FileManager.default.removeItem(atPath: path)
        }
    }
}
