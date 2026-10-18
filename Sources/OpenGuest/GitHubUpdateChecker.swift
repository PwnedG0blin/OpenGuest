import Combine
import Foundation
import OpenGuestCore

enum GitHubUpdateState {
    case idle
    case noReleases
    case upToDate(String?)
    case available(PixelkojeRelease)
    case failed(String)
}

/// Only reads the public GitHub Releases API. No GitHub account is accessed.
@MainActor
final class GitHubUpdateChecker: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var state: GitHubUpdateState = .idle
    @Published private(set) var lastChecked: Date?

    private let lastAttemptKey = "Pixelkoje.GitHubUpdates.lastAttempt"
    let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unbekannt"

    func checkIfDue(includePrereleases: Bool) async {
        if let last = UserDefaults.standard.object(forKey: lastAttemptKey) as? Date,
           Date().timeIntervalSince(last) < 24 * 60 * 60 { return }
        await check(includePrereleases: includePrereleases)
    }

    func check(includePrereleases: Bool) async {
        guard !isChecking else { return }
        guard PixelkojeVersion(installedVersion) != nil else {
            state = .failed("Die installierte App-Version konnte nicht gelesen werden.")
            return
        }
        isChecking = true
        defer { isChecking = false }
        // Prevent repeated automatic requests when GitHub's public rate limit is reached.
        UserDefaults.standard.set(Date(), forKey: lastAttemptKey)

        var request = URLRequest(url: PixelkojeReleaseCatalog.apiURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Pixelkoje/0.3 GitHub-Releases-Check", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                state = .failed("Keine gültige Antwort von GitHub erhalten.")
                return
            }
            guard http.statusCode == 200 else {
                switch http.statusCode {
                case 403, 429:
                    state = .failed("GitHub begrenzt gerade die öffentlichen API-Abfragen. Bitte später erneut prüfen.")
                case 404:
                    state = .failed("Die GitHub-Veröffentlichungen sind momentan nicht erreichbar.")
                default:
                    state = .failed("GitHub antwortet mit HTTP \(http.statusCode). Bitte später erneut prüfen.")
                }
                return
            }
            let releases = try JSONDecoder().decode([PixelkojeRelease].self, from: data)
            lastChecked = Date()
            if releases.isEmpty {
                state = .noReleases
            } else if let next = PixelkojeReleaseCatalog.newerRelease(
                in: releases, installedVersion: installedVersion, includePrereleases: includePrereleases
            ) {
                state = .available(next)
            } else {
                let latest = PixelkojeReleaseCatalog.latestRelease(in: releases, includePrereleases: includePrereleases)
                state = .upToDate(latest?.tagName)
            }
        } catch {
            state = .failed("Die GitHub-Abfrage ist fehlgeschlagen. Prüfe die Internetverbindung und versuche es erneut.")
        }
    }
}
