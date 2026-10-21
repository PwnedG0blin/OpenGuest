import Foundation
import XCTest
@testable import StratovoCore

final class UpdateAssetTests: XCTestCase {
    private func release(url: String? = nil, digest: String? = nil, repository: String = "OpenGuest", releaseURL: String? = nil) throws -> StratovoRelease {
        let data = try JSONSerialization.data(withJSONObject: [
            "tag_name": "v1.0.0-beta.2", "name": "Beta 2",
            "html_url": releaseURL ?? "https://github.com/PwnedG0blin/\(repository)/releases/tag/v1.0.0-beta.2",
            "draft": false, "prerelease": true,
            "assets": [["name": "Stratovo-macOS-AppleSilicon.app.zip", "size": 1234,
                         "browser_download_url": url ?? "https://github.com/PwnedG0blin/\(repository)/releases/download/v1.0.0-beta.2/Stratovo-macOS-AppleSilicon.app.zip",
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
    func testUpdatesWorkBeforeAndAfterRepositoryRename() throws {
        for repository in ["OpenGuest", "Stratovo"] {
            let good = try release(repository: repository)
            XCTAssertTrue(good.hasTrustedURL)
            XCTAssertTrue(try XCTUnwrap(good.assets?.first).isTrusted(for: good))
            XCTAssertEqual(StratovoReleaseCatalog.newerRelease(in: [good], installedVersion: "1.0.0-beta.1", includePrereleases: true)?.tagName, good.tagName)
        }
        XCTAssertEqual(StratovoReleaseCatalog.apiURL.absoluteString,
                       "https://api.github.com/repos/PwnedG0blin/Stratovo/releases?per_page=30")
        XCTAssertEqual(StratovoReleaseCatalog.legacyAPIURL.absoluteString,
                       "https://api.github.com/repos/PwnedG0blin/OpenGuest/releases?per_page=30")
    }

    func testRejectsMixedRepositoriesAndMisleadingReleaseURLs() throws {
        let mixed = try release(url: "https://github.com/PwnedG0blin/OpenGuest/releases/download/v1.0.0-beta.2/Stratovo-macOS-AppleSilicon.app.zip", repository: "Stratovo")
        XCTAssertFalse(try XCTUnwrap(mixed.assets?.first).isTrusted(for: mixed))
        for path in ["Stratovo-other/releases/tag/v1.0.0-beta.2",
                     "Stratovo/releases/tag/v1.0.0-beta.3",
                     "Stratovo/releases/tag/v1.0.0-beta.2/extra",
                     "Stratovo/releases/tag/v1.0.0-beta.2?download=1",
                     "Stratovo/releases/tag/v1.0.0-beta.2#fragment",
                     "%53tratovo/releases/tag/v1.0.0-beta.2"] {
            let bad = try release(releaseURL: "https://github.com/PwnedG0blin/" + path)
            XCTAssertFalse(bad.hasTrustedURL, path)
            XCTAssertFalse(try XCTUnwrap(bad.assets?.first).isTrusted(for: bad), path)
        }
    }

    func testBetaVersionUpdatesToNextBetaThenStableWithoutDowngrade() {
        XCTAssertLessThan(StratovoVersion("1.0.0-beta.1")!, StratovoVersion("v1.0.0-beta.2")!)
        XCTAssertLessThan(StratovoVersion("1.0.0-beta.2")!, StratovoVersion("1.0.0")!)
        XCTAssertGreaterThan(StratovoVersion("1.0.0-beta.1")!, StratovoVersion("0.3.28")!)
    }
}
