import Foundation
import XCTest
@testable import OpenGuestCore

final class GitHubReleaseTests: XCTestCase {
    private func releases() throws -> [PixelkojeRelease] {
        let json = #"""
        [
          {"tag_name":"v0.3.20","name":"Pixelkoje 0.3.20","html_url":"https://github.com/PwnedG0blin/OpenGuest/releases/tag/v0.3.20","body":"Fixes","draft":false,"prerelease":false},
          {"tag_name":"pixelkoje-v0.3.21-beta.1","name":"Beta","html_url":"https://github.com/PwnedG0blin/OpenGuest/releases/tag/pixelkoje-v0.3.21-beta.1","body":null,"draft":false,"prerelease":true},
          {"tag_name":"v0.3.22","name":"Draft","html_url":"https://github.com/PwnedG0blin/OpenGuest/releases/tag/v0.3.22","body":null,"draft":true,"prerelease":false},
          {"tag_name":"v9.0.0","name":"Outside","html_url":"https://example.org/evil","body":null,"draft":false,"prerelease":false}
        ]
        """#
        return try JSONDecoder().decode([PixelkojeRelease].self, from: Data(json.utf8))
    }

    func testParsesAndComparesVersions() {
        XCTAssertTrue(PixelkojeVersion("v0.3.20")! > PixelkojeVersion("0.3.19")!)
        XCTAssertTrue(PixelkojeVersion("0.3.20-beta.1")! < PixelkojeVersion("0.3.20")!)
        XCTAssertEqual(PixelkojeVersion("0.3.20"), PixelkojeVersion("0.3.20.0"))
        XCTAssertNil(PixelkojeVersion("not-a-version"))
    }

    func testSelectsTrustedStableRelease() throws {
        let found = PixelkojeReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.3.19", includePrereleases: false
        )
        XCTAssertEqual(found?.tagName, "v0.3.20")
    }

    func testCanOptIntoPrereleases() throws {
        let found = PixelkojeReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.3.19", includePrereleases: true
        )
        XCTAssertEqual(found?.tagName, "pixelkoje-v0.3.21-beta.1")
    }

    func testIgnoresDraftsAndUntrustedLinks() throws {
        let found = PixelkojeReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.3.21", includePrereleases: false
        )
        XCTAssertNil(found)
    }

    func testNoDowngrade() throws {
        XCTAssertNil(PixelkojeReleaseCatalog.newerRelease(
            in: try releases(), installedVersion: "0.5.0", includePrereleases: true
        ))
    }
}
