import SwiftUI
import OpenGuestCore

/// Opt-in release checks in the existing Setup screen; no automatic installation.
struct GitHubUpdatesView: View {
    @StateObject private var checker = GitHubUpdateChecker()
    @AppStorage("Pixelkoje.GitHubUpdates.automatic") private var automaticChecks = false
    @AppStorage("Pixelkoje.GitHubUpdates.prereleases") private var includePrereleases = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pixelkoje-Updates über GitHub", systemImage: "arrow.triangle.2.circlepath")
                .font(.title2.bold())

            Text("Versionsprüfung über die öffentliche GitHub-API – ohne Anmeldung, API-Schlüssel oder Telemetrie.")
                .foregroundStyle(.secondary)

            HStack {
                Text("Installiert: \(checker.installedVersion)")
                Spacer()
                Button {
                    Task { await checker.check(includePrereleases: includePrereleases) }
                } label: {
                    Label("Auf Updates prüfen", systemImage: "arrow.clockwise")
                }
                .disabled(checker.isChecking)
                if checker.isChecking { ProgressView().controlSize(.small) }
            }
            Toggle("Automatisch höchstens einmal täglich prüfen", isOn: $automaticChecks)
                .onChange(of: automaticChecks) { _, enabled in
                    if enabled { Task { await checker.checkIfDue(includePrereleases: includePrereleases) } }
                }
            Toggle("Vorabversionen berücksichtigen", isOn: $includePrereleases)

            switch checker.state {
            case .idle:
                Text("Noch keine Versionsprüfung in dieser Sitzung durchgeführt.")
                    .foregroundStyle(.secondary)
            case .noReleases:
                Label("Noch keine GitHub Releases veröffentlicht. Test-Builds stehen gegebenenfalls über GitHub Actions bereit.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            case .upToDate(let latest):
                Label(latest.map { "Keine neuere Veröffentlichung gefunden (neueste: \($0))." }
                      ?? "Keine passende Veröffentlichung gefunden.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            case .available(let release):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Neue Version gefunden: \(release.name?.isEmpty == false ? release.name! : release.tagName)", systemImage: "arrow.down.circle")
                        .font(.headline)
                    if let notes = release.body, !notes.isEmpty {
                        Text(notes).lineLimit(6).textSelection(.enabled)
                            .font(.subheadline)
                    }
                    Link("Veröffentlichung und Downloads öffnen ↗", destination: release.htmlURL)
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if let checked = checker.lastChecked {
                Text("Zuletzt geprüft: \(checked.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Link("Releases ↗", destination: PixelkojeReleaseCatalog.releasesURL)
                Link("Aktuelle Test-Builds ↗", destination: PixelkojeReleaseCatalog.buildsURL)
            }
            .font(.subheadline)
            Text("Updates werden nicht automatisch heruntergeladen oder installiert. Die Versionsprüfung vergleicht veröffentlichte Releases; Actions-Testartefakte gelten nicht als Releases.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .task {
            if automaticChecks { await checker.checkIfDue(includePrereleases: includePrereleases) }
        }
    }
}
