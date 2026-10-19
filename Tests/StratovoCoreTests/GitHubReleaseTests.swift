import Foundation
import XCTest
@testable import StratovoCore

final class GitHubReleaseTests: XCTestCase {
    func testRenamedAndLegacyReleaseTagsCompareAsSameVersion() {
        XCTAssertEqual(StratovoVersion("stratovo-v0.3.26"), StratovoVersion("pixelkoje-v0.3.26"))
        XCTAssertEqual(StratovoVersion("stratovo-v0.3.26"), StratovoVersion("0.3.26"))
    }

    private func releases() throws -> [StratovoRelease] {
        let json = #"""
        [
          {"tag_name":"v0.3.20","name":"Stratovo 0.3.20","html_url":"https://github.com/PwnedG0blin/OpenGuest/releases/tag/v0.3.20","body":"Fixes","draft":false,"prerelease":false},
          {"tag_name":"pixelkoje-v0.3.21-beta.1","name":"Beta","html_url":"https://github.com/PwnedG0blin/OpenGuest/releases/tag/pixelkoje-v0.3.21-beta.1","body":null,"draft":false,"prerelease":true},
          {"tag_name":"v0.3.22","name":"Draft","html_url":"https://github.com/PwnedG0blin/OpenGuest/releases/tag/v0.3.22","body":null,"draft":true,"prerelease":false},
          {"tag_name":"v9.0.0","name":"Outside","html_url":"https://example.org/evil","body":null,"draft":false,"prerelease":false}
        ]
        """#
        return try JSONDecoder().decode([StratovoRelease].self, from: Data(json.utf8))
    }

    func testParsesAndComparesVersions() {
        XCTAssertTrue(StratovoVersion("v0.3.20")! > StratovoVersion("0.3.19")!)
        XCTAssertTrue(StratovoVersion("0.3.20-beta.1")! < StratovoVersion("0.3.20")!)
        XCTAssertEqual(StratovoVersion("0.3.20"), StratovoVersion("0.3.20.0"))
        XCTAssertNil(StratovoVersion("not-a-version"))
    }

    func testSelectsTrustedStableRelease() throws {
        let found = StratovoReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.3.19", includePrereleases: false
        )
        XCTAssertEqual(found?.tagName, "v0.3.20")
    }

    func testCanOptIntoPrereleases() throws {
        let found = StratovoReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.3.19", includePrereleases: true
        )
        XCTAssertEqual(found?.tagName, "pixelkoje-v0.3.21-beta.1")
    }

    func testIgnoresDraftsAndUntrustedLinks() throws {
        let found = StratovoReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.3.21", includePrereleases: false
        )
        XCTAssertNil(found)
    }

    func testNoDowngrade() throws {
        XCTAssertNil(StratovoReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.5.0", includePrereleases: true
        ))
    }
}
