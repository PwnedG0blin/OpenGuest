import Foundation

public enum AndroidPerformance: String, CaseIterable, Hashable {
    case smooth, balanced, native
    public var title: String {
        switch self {
        case .smooth: return L10n.text("Flüssig · empfohlen")
        case .balanced: return "Ausgewogen"
        case .native: return L10n.text("Originalauflösung")
        }
    }
    public var guestMaxSize: Int { self == .smooth ? 1600 : (self == .balanced ? 2000 : 0) }
}

public struct AndroidCustomDisplay: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let density: Int
    public init(width: Int, height: Int, density: Int) throws {
        guard (320...4096).contains(width), (320...4096).contains(height),
              width.isMultiple(of: 2), height.isMultiple(of: 2), width * height <= 8_388_608,
              (72...960).contains(density) else {
            throw GuestError.commandFailed(1, "Breite/Höhe: gerade Zahlen von 320–4096 Pixeln, insgesamt höchstens 8,4 Megapixel. Dichte: 72–960 dpi.")
        }
        self.width = width; self.height = height; self.density = density
    }
}

public struct AndroidDisplayPlan {
    public let commands: [[String]]
    public let rollback: [[String]]
    public let summary: String
    public init(sizeOutput: String, densityOutput: String, profile: AndroidPerformance, custom: AndroidCustomDisplay? = nil) throws {
        let physical = try Self.size(in: sizeOutput, prefix: "Physical size:")
        let density = try Self.density(in: densityOutput, prefix: "Physical density:")
        let oldSize = try? Self.size(in: sizeOutput, prefix: "Override size:")
        let oldDensity = try? Self.density(in: densityOutput, prefix: "Override density:")
        rollback = [["wm", "size", oldSize.map { "\($0.0)x\($0.1)" } ?? "reset"],
                    ["wm", "density", oldDensity.map(String.init) ?? "reset"]]
        if let custom {
            commands = [["wm", "size", "\(custom.width)x\(custom.height)"], ["wm", "density", "\(custom.density)"]]
            summary = "Android: \(custom.width) × \(custom.height) · \(custom.density) dpi · eigene Anzeige"
        } else if profile == .native {
            commands = [["wm", "size", "reset"], ["wm", "density", "reset"]]
            summary = "Original: \(physical.0) × \(physical.1) · \(density) dpi"
        } else {
            let scale = min(1, Double(profile.guestMaxSize) / Double(max(physical.0, physical.1)))
            let width = max(2, Int(Double(physical.0) * scale) / 2 * 2)
            let height = max(2, Int(Double(physical.1) * scale) / 2 * 2)
            let dpi = max(72, Int((Double(density) * scale).rounded()))
            commands = [["wm", "size", "\(width)x\(height)"], ["wm", "density", "\(dpi)"]]
            summary = "Android: \(width) × \(height) · \(dpi) dpi"
        }
    }
    private static func value(in text: String, prefix: String) throws -> String {
        guard let line = text.components(separatedBy: .newlines).first(where: { $0.hasPrefix(prefix) }) else {
            throw GuestError.commandFailed(1, "Android-Bildschirmwerte konnten nicht gelesen werden.")
        }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
    private static func size(in text: String, prefix: String) throws -> (Int, Int) {
        let parts = try value(in: text, prefix: prefix).split(separator: "x")
        guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]),
              (200...8192).contains(w), (200...8192).contains(h) else { throw GuestError.invalidResources }
        return (w, h)
    }
    private static func density(in text: String, prefix: String) throws -> Int {
        guard let dpi = Int(try value(in: text, prefix: prefix)), (72...1600).contains(dpi) else { throw GuestError.invalidResources }
        return dpi
    }
}

public struct AndroidRenderer {
    public enum Kind: Equatable { case unknown, software, hardware }
    public let kind: Kind
    public let summary: String
    public static func inspect(_ text: String) -> AndroidRenderer {
        if text.lowercased().contains("forcing software rendering") {
            return AndroidRenderer(kind: .software, summary: "Softwaregrafik vom Emulator erzwungen · GPU-Anforderung wurde übergangen")
        }
        let evidence = text.components(separatedBy: .newlines).filter {
            $0.contains("Graphics Adapter") || $0.contains("Selecting Vulkan device:") || $0.contains("emuglConfig_init:")
        }.joined(separator: " ").lowercased()
        if ["swiftshader", "llvmpipe", "lavapipe", "swangle"].contains(where: evidence.contains) {
            return AndroidRenderer(kind: .software, summary: "Softwaregrafik erkannt · Grafikberechnung belastet die CPU")
        }
        if evidence.contains("apple") && !evidence.contains("apple software") {
            return AndroidRenderer(kind: .hardware, summary: "Apple-GPU im aktiven Grafikrenderer erkannt")
        }
        return AndroidRenderer(kind: .unknown, summary: "Grafikrenderer noch nicht eindeutig erkannt")
    }
}
