import Foundation

/// Public GitHub Releases for Stratovo. No login or API token is required.
public struct StratovoRelease: Decodable, Sendable {
    public let tagName: String
    public let name: String?
    public let htmlURL: URL
    public let body: String?
    public let draft: Bool
    public let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body, draft, prerelease
    }

    public var version: StratovoVersion? { StratovoVersion(tagName) }

    /// Never offer a download link outside this project's official releases.
    public var hasTrustedURL: Bool {
        guard let parts = URLComponents(url: htmlURL, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https",
              parts.host?.lowercased() == "github.com",
              parts.user == nil, parts.password == nil, parts.port == nil else { return false }
        let prefix = "/PwnedG0blin/OpenGuest/releases/tag/"
        return parts.path.hasPrefix(prefix) && parts.path.count > prefix.count
    }
}

/// Compares versions such as 0.3.19, v0.3.20 and pixelkoje-v0.3.21-beta.
public struct StratovoVersion: Comparable, Sendable {
    private let numbers: [Int]
    private let suffix: String?

    public init?(_ text: String) {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["stratovo-", "pixelkoje-"] {
            if normalized.lowercased().hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
                break
            }
        }
        if normalized.lowercased().hasPrefix("v") {
            normalized = String(normalized.dropFirst())
        }
        let pieces = normalized.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numericParts = pieces[0].split(separator: ".", omittingEmptySubsequences: false)
        guard (2...4).contains(numericParts.count) else { return nil }
        var parsed: [Int] = []
        for part in numericParts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(part) else { return nil }
            parsed.append(value)
        }
        if pieces.count == 2 && pieces[1].isEmpty { return nil }
        numbers = parsed
        suffix = pieces.count == 2 ? String(pieces[1]).lowercased() : nil
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        for index in 0..<max(lhs.numbers.count, rhs.numbers.count) {
            let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
            let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
            if left != right { return left < right }
        }
        switch (lhs.suffix, rhs.suffix) {
        case (nil, nil): return false
        case (.some, nil): return true
        case (nil, .some): return false
        case let (.some(left), .some(right)): return left.compare(right, options: .numeric) == .orderedAscending
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

public enum StratovoReleaseCatalog {
    public static let apiURL = URL(string: "https://api.github.com/repos/PwnedG0blin/OpenGuest/releases?per_page=30")!
    public static let releasesURL = URL(string: "https://github.com/PwnedG0blin/OpenGuest/releases")!
    public static let buildsURL = URL(string: "https://github.com/PwnedG0blin/OpenGuest/actions/workflows/macos.yml")!

    public static func latestRelease(in releases: [StratovoRelease], includePrereleases: Bool) -> StratovoRelease? {
        releases.filter { release in
            !release.draft && (includePrereleases || !release.prerelease) &&
            release.hasTrustedURL && release.version != nil
        }.max { lhs, rhs in
            guard let left = lhs.version, let right = rhs.version else { return false }
            return left < right
        }
    }

    public static func newerRelease(in releases: [StratovoRelease],
                                    installedVersion: String,
                                    includePrereleases: Bool) -> StratovoRelease? {
        guard let installed = StratovoVersion(installedVersion),
              let latest = latestRelease(in: releases, includePrereleases: includePrereleases),
              let version = latest.version, installed < version else { return nil }
        return latest
    }
}
