import Foundation

public enum WorkspaceArtwork {
    public static func url(for kind: String) -> URL? {
        let name: String
        switch kind {
        case "windows": name = "MidnightWindows"
        case "android": name = "MidnightAndroid"
        case "ubuntu": name = "MidnightUbuntu"
        default: return nil
        }
        // Resolve within the installed app, never SwiftPM's original build path.
        guard let resources = L10n.resourceURL(in: .main) else { return nil }
        let url = resources.appendingPathComponent(name + ".png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
