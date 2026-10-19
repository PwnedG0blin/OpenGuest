import Foundation
import XCTest
@testable import StratovoCore

final class UpdateAssetTests: XCTestCase {
    private func release(url: String? = nil, digest: String? = nil) throws -> StratovoRelease {
        let data = try JSONSerialization.data(withJSONObject: [
            "tag_name": "v1.0.0-beta.2", "name": "Beta 2",
            "html_url": "https://github.com/PwnedG0blin/OpenGuest/releases/tag/v1.0.0-beta.2",
            "draft": false, "prerelease": true,
            "assets": [["name": "Stratovo-macOS-AppleSilicon.app.zip", "size": 1234,
                         "browser_download_url": url ?? "https://github.com/PwnedG0blin/OpenGuest/releases/download/v1.0.0-beta.2/Stratovo-macOS-AppleSilicon.app.zip",
                         "digest": digest ?? "sha256:" + String(repeating: "a", count: 64)]]
        ])
        return try JSONDecoder().decode(StratovoRelease.self, from: data)
    }
    func testOnlyCorrectRepositoryTagAndDigestCanBeInstalled() throws {
        let good = try release()
        XCTAssertTrue(try XCTUnwrap(good.assets?.first).isTrusted(for: good))
        for url in ["https://example.com/update.zip", "https://github.com/Other/Repo/releases/download/v1.0.0-beta.2/Stratovo-macOS-AppleSilicon.app.zip", "https://github.com/PwnedG0blin/OpenGuest/releases/download/v1.0.0/Stratovo-macOS-AppleSilicon.app.zip"] {
            let bad = try release(url: url)
            XCTAssertFalse(try XCTUnwrap(bad.assets?.first).isTrusted(for: bad))
        }
        for digest in ["sha256:bad", "md5:" + String(repeating: "a", count: 64)] {
            let bad = try release(digest: digest)
            XCTAssertFalse(try XCTUnwrap(bad.assets?.first).isTrusted(for: bad))
        }
    }
    func testBetaVersionUpdatesToNextBetaThenStableWithoutDowngrade() {
        XCTAssertLessThan(StratovoVersion("1.0.0-beta.1")!, StratovoVersion("v1.0.0-beta.2")!)
        XCTAssertLessThan(StratovoVersion("1.0.0-beta.2")!, StratovoVersion("1.0.0")!)
        XCTAssertGreaterThan(StratovoVersion("1.0.0-beta.1")!, StratovoVersion("0.3.28")!)
    }
}
