import Foundation
import StratovoCore

/// Never forward the repository credential to artifact storage redirects.
final class PrivateUpdateNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct PrivateUpdateAPI {
    static let repository = "https://api.github.com/repos/PwnedG0blin/Stratovo-Private"
    let token: String

    private func request(_ path: String, accept: String = "application/vnd.github+json") -> URLRequest {
        var request = URLRequest(url: URL(string: Self.repository + path)!)
        request.timeoutInterval = 180
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Stratovo-Private-Updates", forHTTPHeaderField: "User-Agent")
        return request
    }
    private func response(_ path: String, accept: String = "application/vnd.github+json") async throws -> (Data, HTTPURLResponse) {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        let session = URLSession(configuration: config, delegate: PrivateUpdateNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request(path, accept: accept))
        guard let http = response as? HTTPURLResponse else { throw Self.failure("Keine gültige Antwort von GitHub.") }
        guard http.statusCode == 200 || http.statusCode == 302 else {
            switch http.statusCode {
            case 401: throw Self.failure("GitHub-Zugang abgelaufen oder ungültig. Bitte erneut verbinden.")
            case 403, 404: throw Self.failure("Kein Zugriff auf private Builds. Der GitHub-Zugang benötigt für Stratovo-Private die Berechtigung Actions: Read-only. Prüfe auch Ablaufdatum und GitHub-Abfragelimit.")
            default: throw Self.failure("GitHub ist gerade nicht erreichbar. Bitte später erneut versuchen.")
            }
        }
        return (data, http)
    }
    func latest() async throws -> PrivateUpdateArtifact? {
        struct Runs: Decodable { let workflow_runs: [PrivateUpdateRun] }
        struct Artifacts: Decodable { let artifacts: [PrivateUpdateArtifact] }
        let (data, response) = try await response("/actions/workflows/private-macos.yml/runs?branch=main&status=success&per_page=20")
        guard response.statusCode == 200 else { throw Self.failure("GitHub-Buildliste konnte nicht geladen werden.") }
        let runs = try JSONDecoder().decode(Runs.self, from: data).workflow_runs.filter(\.eligible)
        let successful = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        let (artifactsData, artifactsResponse) = try await self.response("/actions/artifacts?per_page=100")
        guard artifactsResponse.statusCode == 200 else { throw Self.failure("GitHub-Buildliste konnte nicht geladen werden.") }
        let candidates = try JSONDecoder().decode(Artifacts.self, from: artifactsData).artifacts.filter { artifact in
            guard let run = successful[artifact.workflowRun.id] else { return false }
            return artifact.isTrusted(run: run)
        }
        return candidates.max(by: { ($0.build ?? 0) < ($1.build ?? 0) })
    }

    func download(_ artifact: PrivateUpdateArtifact) async throws -> Data {
        guard artifact.id > 0, artifact.sha256 != nil, artifact.size <= 100 * 1024 * 1024 else {
            throw Self.failure("Ungültiges privates Updatepaket.")
        }
        let (data, response) = try await response("/actions/artifacts/\(artifact.id)/zip", accept: "application/vnd.github+json")
        if response.statusCode == 200 { return data }
        guard let location = response.value(forHTTPHeaderField: "Location"), let url = URL(string: location),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else {
            throw Self.failure("GitHub liefert keinen gültigen Download.")
        }
        // Separate anonymous session: no token, cookies or stored credentials.
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url); request.timeoutInterval = 180
        let (download, result) = try await session.data(for: request)
        guard (result as? HTTPURLResponse)?.statusCode == 200 else { throw Self.failure("Privater Update-Download fehlgeschlagen. Bitte erneut prüfen.") }
        return download
    }
    static func failure(_ message: String) -> NSError {
        NSError(domain: "Stratovo.PrivateUpdates", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.text(message)])
    }
}
