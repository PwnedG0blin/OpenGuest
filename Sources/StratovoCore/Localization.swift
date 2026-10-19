import Foundation

/// Separate standard .lproj folders. Technical logs are intentionally left intact.
public enum L10n {
    public static let preferenceKey = "Stratovo.interfaceLanguage"
    public static let languages: [(code: String, name: String)] = [
        ("de", "Deutsch"), ("en", "English"), ("fr", "Français"), ("es", "Español"),
        ("it", "Italiano"), ("pt", "Português"), ("nl", "Nederlands"), ("pl", "Polski"),
        ("tr", "Türkçe"), ("uk", "Українська"), ("ar", "العربية"),
        ("zh-Hans", "简体中文"), ("ja", "日本語"), ("ko", "한국어")
    ]
    public static func resolve(preference: String, preferredLanguages: [String]) -> String {
        let supported = Set(languages.map(\.code))
        if supported.contains(preference) { return preference }
        for language in preferredLanguages {
            let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
            if normalized.hasPrefix("zh") { return "zh-Hans" }
            if let match = languages.first(where: { normalized == $0.code.lowercased() || normalized.hasPrefix($0.code.lowercased() + "-") }) { return match.code }
        }
        return "en"
    }
    public static var code: String {
        resolve(preference: UserDefaults.standard.string(forKey: preferenceKey) ?? "system",
                preferredLanguages: Locale.preferredLanguages)
    }
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: languages.compactMap { language in
        // SwiftPM normalizes localization folder names (zh-Hans → zh-hans).
        guard let resources = Bundle.module.resourceURL else { return nil }
        let folders = (try? FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)) ?? []
        guard let folder = folders.first(where: { $0.lastPathComponent.lowercased() == language.code.lowercased() + ".lproj" }),
              let bundle = Bundle(url: folder) else { return nil }
        return (language.code, bundle)
    })
    public static func text(_ key: String, language: String? = nil) -> String {
        let code = language ?? self.code
        func lookup(_ code: String) -> String? {
            guard let bundle = bundles[code] else { return nil }
            let result = bundle.localizedString(forKey: key, value: "__STRATOVO_MISSING__", table: nil)
            return result == "__STRATOVO_MISSING__" ? nil : result
        }
        return lookup(code) ?? lookup("en") ?? key
    }
}

public struct LocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let key: String
    let arguments: [String]
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key; arguments = stringInterpolation.arguments
    }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) { }
        public mutating func appendLiteral(_ literal: String) { key += literal }
        public mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(arguments.count)}"; arguments.append(String(describing: value))
        }
    }
}

extension L10n {
    public static func message(_ message: LocalizedMessage, language: String? = nil) -> String {
        let template = text(message.key, language: language)
        let pattern = try! NSRegularExpression(pattern: #"\{([0-9]+)\}"#)
        let result = NSMutableString(string: template)
        for match in pattern.matches(in: template, range: NSRange(location: 0, length: (template as NSString).length)).reversed() {
            let raw = (template as NSString).substring(with: match.range(at: 1))
            if let index = Int(raw), message.arguments.indices.contains(index) {
                result.replaceCharacters(in: match.range, with: message.arguments[index])
            }
        }
        return result as String
    }
}
