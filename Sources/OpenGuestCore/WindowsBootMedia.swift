import Foundation

public struct WindowsISOInfo {
    public let path: String
    public let bytes: Int64
    public static func check(path: String) throws -> WindowsISOInfo {
        let url = URL(fileURLWithPath: path)
        let target = url.resolvingSymlinksInPath()
        let fm = FileManager.default
        guard path.hasPrefix("/"), url.pathExtension.lowercased() == "iso", fm.isReadableFile(atPath: path),
              let attributes = try? fm.attributesOfItem(atPath: target.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let bytes = (attributes[.size] as? NSNumber)?.int64Value, bytes > 0 else {
            throw StorageMigration.failure("Bitte eine vorhandene, lesbare Windows-ARM64-ISO auswählen. Die Datei darf nicht leer sein.")
        }
        return WindowsISOInfo(path: path, bytes: bytes)
    }
}

public struct WindowsBootEvidence {
    public let machineStatus: String
    public let dvdConnected: Bool
    public let dvdPath: String?
    public init(status: Data, blocks: Data) throws {
        guard let state = try JSONSerialization.jsonObject(with: status) as? [String: Any],
              let name = state["status"] as? String,
              let drives = try JSONSerialization.jsonObject(with: blocks) as? [[String: Any]] else {
            throw StorageMigration.failure("QEMU-Startstatus ist nicht lesbar.")
        }
        machineStatus = name == "running" ? "Virtuelle Maschine läuft" : "QEMU-Zustand: \(name)"
        let dvd = drives.first { drive in
            let id = drive["qdev"] as? String ?? ""
            return id == "installer-cd" || id.hasSuffix("/installer-cd")
        }
        let inserted = dvd?["inserted"] as? [String: Any]
        dvdConnected = inserted != nil && dvd?["tray_open"] as? Bool != true && inserted?["ro"] as? Bool == true
        dvdPath = dvdConnected ? inserted?["file"] as? String : nil
    }
}
