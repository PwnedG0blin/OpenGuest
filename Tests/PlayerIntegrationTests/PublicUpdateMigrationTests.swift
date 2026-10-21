import Foundation
import XCTest
import StratovoCore
@testable import Stratovo

final class PublicUpdateMigrationTests: XCTestCase {
    @MainActor
    func testFallbackBeforeRenameAndCanonicalResponseAfterRename() async throws {
        for renamed in [false, true] {
            var requested: [URL] = []
            let checker = GitHubUpdateChecker(installedVersion: "1.0.0-beta.7.1") { request in
                let url = try XCTUnwrap(request.url)
                requested.append(url)
                let missing = !renamed && url == StratovoReleaseCatalog.apiURL
                let repository = renamed ? "Stratovo" : "OpenGuest"
                let body = """
                [{"tag_name":"v1.0.0-beta.7.2","html_url":"https://github.com/PwnedG0blin/\(repository)/releases/tag/v1.0.0-beta.7.2","draft":false,"prerelease":true}]
                """
                return (Data((missing ? "{}" : body).utf8), try XCTUnwrap(HTTPURLResponse(url: url, statusCode: missing ? 404 : 200, httpVersion: nil, headerFields: nil)))
            }
            await checker.check(includePrereleases: true)
            XCTAssertEqual(requested, renamed ? [StratovoReleaseCatalog.apiURL] : [StratovoReleaseCatalog.apiURL, StratovoReleaseCatalog.legacyAPIURL])
            guard case .available(let release) = checker.state else { return XCTFail("Migration update was not offered") }
            XCTAssertEqual(release.tagName, "v1.0.0-beta.7.2")
        }
    }

    @MainActor
    func testRateLimitDoesNotFallBackToAnotherRequest() async throws {
        var requests = 0
        let checker = GitHubUpdateChecker(installedVersion: "1.0.0-beta.7.1") { request in
            requests += 1
            return (Data(), try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 403, httpVersion: nil, headerFields: nil)))
        }
        await checker.check(includePrereleases: true)
        XCTAssertEqual(requests, 1)
        guard case .failed = checker.state else { return XCTFail("Expected rate-limit error") }
    }
}
