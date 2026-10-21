import XCTest
@testable import Stratovo

final class PrivateUpdateRedirectTests: XCTestCase {
    func testAuthenticatedSessionNeverFollowsArtifactRedirect() throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let api = URL(string: PrivateUpdateAPI.repository + "/actions/artifacts/123/zip")!
        let response = try XCTUnwrap(HTTPURLResponse(url: api, statusCode: 302, httpVersion: nil,
                                                   headerFields: ["Location": "https://artifact.example.invalid/file"]))
        var incoming = URLRequest(url: URL(string: "https://artifact.example.invalid/file")!)
        incoming.setValue("Bearer test-credential", forHTTPHeaderField: "Authorization")
        let task = session.dataTask(with: URLRequest(url: api)) // Never resumed; no network traffic.
        var invoked = false
        PrivateUpdateNoRedirect().urlSession(session, task: task, willPerformHTTPRedirection: response,
                                            newRequest: incoming) { forwarded in
            invoked = true
            XCTAssertNil(forwarded, "An authenticated request must stop at the GitHub API.")
        }
        XCTAssertTrue(invoked)
    }
}
