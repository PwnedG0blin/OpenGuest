import Foundation

public enum SetupComponent: String, CaseIterable, Identifiable {
    case android, streaming, windowsDrivers, windowsISO
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .android: return "Android 15 mit Google Play"
        case .streaming: return "Android-Videostream"
        case .windowsDrivers: return "Windows-ARM64-Treiber"
        case .windowsISO: return "Windows 11 ARM64 · Installations-ISO"
        }
    }
    public var script: String? {
        switch self {
        case .android: return "Android_einrichten.command"
        case .streaming: return "Android_Streaming_einrichten.command"
        case .windowsDrivers: return "Windows_Treiber_einrichten.command"
        case .windowsISO: return nil
        }
    }
}

public enum SetupDownloads {
    public static func isLicensePrompt(_ output: String) -> Bool {
        String(output.suffix(500)).range(of: #"(?i)\(y/n\)[:?]?\s*$"#, options: .regularExpression) != nil
    }
    /// Accept a Microsoft ISO link, never a shell command or arbitrary executable.
    public static func windowsISOURL(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host?.lowercased(),
              host == "microsoft.com" || host.hasSuffix(".microsoft.com"),
              url.user == nil, url.password == nil, url.fragment == nil,
              url.port == nil || url.port == 443, url.path.lowercased().hasSuffix(".iso") else {
            throw StorageMigration.failure("Bitte den direkten HTTPS-Downloadlink der ARM64-ISO von Microsoft einfügen. Die Adresse muss auf .iso enden; angehängte Downloadparameter sind erlaubt.")
        }
        return url
    }
}
