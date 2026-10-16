import CryptoKit
import Foundation

public struct WindowsISOHash: Sendable {
    public let sha256: String
    public let matchesMicrosoftGerman26H2: Bool
    /// Microsoft download page, German Windows 11 26H2 ARM64, checked 2026-10-16.
    public static let microsoftGerman26H2 = "bbf9f2284fe7559ea8bdf960851a80231eada3aa7e740958948b79ab01d23478"
    public static let source = "https://www.microsoft.com/de-de/software-download/windows11arm64"

    public static func calculate(path: String) throws -> Self {
        let info = try WindowsISOInfo.check(path: path)
        let target = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let before = try FileManager.default.attributesOfItem(atPath: target.path)
        let input = try FileHandle(forReadingFrom: target)
        defer { try? input.close() }
        var hash = SHA256()
        var bytes: Int64 = 0
        while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
            bytes += Int64(chunk.count)
        }
        let after = try FileManager.default.attributesOfItem(atPath: target.path)
        guard bytes == info.bytes,
              (before[.systemFileNumber] as? NSNumber) == (after[.systemFileNumber] as? NSNumber),
              (before[.size] as? NSNumber) == (after[.size] as? NSNumber),
              (before[.modificationDate] as? Date) == (after[.modificationDate] as? Date),
              URL(fileURLWithPath: path).resolvingSymlinksInPath() == target else {
            throw StorageMigration.failure("Die ISO wurde während der Prüfsummenberechnung verändert. Bitte erneut prüfen.")
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        return Self(sha256: digest, matchesMicrosoftGerman26H2: digest == microsoftGerman26H2)
    }
}
