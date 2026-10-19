import SwiftUI
import StratovoCore

/// Explicit release checks and user-initiated verified app replacement.
struct GitHubUpdatesView: View {
    @ObservedObject var model: AppModel
    var compact = false
    @StateObject private var installer = AppUpdateInstaller()
    @State private var confirmInstall = false
    @State private var showSettings = false
    @StateObject private var checker = GitHubUpdateChecker()
    @AppStorage("Pixelkoje.GitHubUpdates.automatic") private var automaticChecks = false
    @AppStorage("Pixelkoje.GitHubUpdates.prereleases") private var includePrereleases = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stratovo-Updates über GitHub", systemImage: "arrow.triangle.2.circlepath")
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
                .disabled(checker.isChecking || installer.busy)
                if checker.isChecking { ProgressView().controlSize(.small) }
            }
            DisclosureGroup("Update-Einstellungen und Hinweise", isExpanded: $showSettings) {
            Toggle("Automatisch höchstens einmal täglich prüfen", isOn: $automaticChecks)
                .onChange(of: automaticChecks) { _, enabled in
                    if enabled { Task { await checker.checkIfDue(includePrereleases: includePrereleases) } }
                }
            Toggle("Vorabversionen berücksichtigen", isOn: $includePrereleases)

            }
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
                    Label("Neue Version gefunden: \(release.name.flatMap { $0.isEmpty ? nil : $0 } ?? release.tagName)", systemImage: "arrow.down.circle")
                        .font(.headline)
                    if let notes = release.body, !notes.isEmpty {
                        Text(notes).lineLimit(6).textSelection(.enabled)
                            .font(.subheadline)
                    }
                    Button("Update laden und installieren …") { confirmInstall = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(installer.busy || model.busy || model.running || model.graphicsLab.active || !(release.assets?.contains(where: { $0.isTrusted(for: release) }) ?? false))
                        .confirmationDialog("Stratovo aktualisieren und neu starten?", isPresented: $confirmInstall) {
                            Button("Update installieren") { Task { await installer.install(release, model: model) } }
                            Button("Abbrechen", role: .cancel) { }
                        } message: { Text("Die App wird nach Prüfsummen- und Versionsprüfung ersetzt. Deine VMs bleiben im gewählten Datenordner. Eine Kopie der bisherigen App bleibt für die Rückkehr neben der App erhalten.") }
                    Link("Veröffentlichung und Downloads öffnen ↗", destination: release.htmlURL)
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if !installer.status.isEmpty { Text(installer.status).textSelection(.enabled) }
            if installer.busy { ProgressView() }
            if let checked = checker.lastChecked {
                Text("Zuletzt geprüft: \(checked.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Link("Releases ↗", destination: StratovoReleaseCatalog.releasesURL)
                Link("Aktuelle Test-Builds ↗", destination: StratovoReleaseCatalog.buildsURL)
            }
            .font(.subheadline)
            if !compact { Text("Ein Klick prüft die Version. Installiert wird erst nach deiner Auswahl und Bestätigung, wenn alle Gäste beendet sind. Downloads und Prüfung liegen im gewählten Datenordner. Öffentliche GitHub Releases benötigen keinen API-Schlüssel; Actions-Artefakte sind keine Releases.")
                .font(.caption).foregroundStyle(.secondary) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .task {
            if automaticChecks { await checker.checkIfDue(includePrereleases: includePrereleases) }
        }
    }
}
