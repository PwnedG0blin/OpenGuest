import XCTest
import CryptoKit
@testable import Stratovo

final class PrivateUpdatePackageTests: XCTestCase {
    func testPrivateArtifactPreservesExecutableAndRejectsMismatchedBuildAndHash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Stratovo.app")
        let macOS = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Fixture.c")
        try Data("int main(void) { return 0; }\n".utf8).write(to: source)
        try UpdatePackagePreparer.run("/usr/bin/xcrun", ["clang", "-arch", "arm64", source.path,
                                                       "-o", macOS.appendingPathComponent("Stratovo").path])
        let info: [String: String] = ["CFBundleIdentifier": "org.pwnedg0blin.openguest", "CFBundleExecutable": "Stratovo",
            "CFBundlePackageType": "APPL", "CFBundleVersion": "1024", "StratovoBuildFlavor": "private"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        try UpdatePackagePreparer.run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        let inner = root.appendingPathComponent("Private-App.zip")
        try UpdatePackagePreparer.run("/usr/bin/ditto", ["-c", "-k", "--norsrc", "--keepParent", app.path, inner.path])
        let outer = root.appendingPathComponent("Artifact.zip")
        try UpdatePackagePreparer.run("/usr/bin/zip", ["-j", outer.path, inner.path])
        let data = try Data(contentsOf: outer)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        func stage() throws -> URL {
            let path = root.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            return path
        }
        let prepared = try UpdatePackagePreparer.prepare(data: data, sha256: hash, size: Int64(data.count), directory: stage(), privateBuild: 1024)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: prepared.appendingPathComponent("Contents/MacOS/Stratovo").path))
        XCTAssertThrowsError(try UpdatePackagePreparer.prepare(data: data, sha256: hash, size: Int64(data.count), directory: stage(), privateBuild: 1025))
        XCTAssertThrowsError(try UpdatePackagePreparer.prepare(data: data, sha256: String(repeating: "0", count: 64), size: Int64(data.count), directory: stage(), privateBuild: 1024))
        XCTAssertThrowsError(try UpdatePackagePreparer.prepare(data: data, sha256: hash, size: Int64(data.count) + 1, directory: stage(), privateBuild: 1024))
    }
}
