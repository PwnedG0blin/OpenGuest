import Combine
import Foundation
import StratovoCore

@MainActor
final class PrivateUpdateController: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var status = "GitHub einmalig verbinden, um private Updates direkt zu installieren."
    @Published private(set) var available: PrivateUpdateArtifact?
    private var token: String?
    private var restored = false
    private let lastAttemptKey = "Stratovo.privateUpdates.lastAttempt"
    private var installedBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }
    func restore() {
        guard !restored else { return }; restored = true
        do {
            token = try PrivateUpdateCredential.read(); connected = token != nil
            if connected { status = "Privater Updatekanal verbunden." }
        } catch { status = error.localizedDescription }
    }
    func connect(_ input: String) async -> Bool {
        guard !busy else { return false }
        let candidate = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !candidate.contains("\n"), !candidate.contains("\r") else { return false }
        busy = true; available = nil; status = "GitHub-Zugang wird geprüft …"
        defer { busy = false }
        do {
            let latest = try await PrivateUpdateAPI(token: candidate).latest()
            try PrivateUpdateCredential.save(candidate)
            token = candidate; connected = true; update(latest)
            UserDefaults.standard.set(Date(), forKey: lastAttemptKey)
            return true
        } catch { status = safeMessage(error); return false }
    }
    func disconnect() {
        guard !busy else { return }
        do {
            try PrivateUpdateCredential.remove(); token = nil; connected = false; available = nil
            UserDefaults.standard.removeObject(forKey: lastAttemptKey)
            status = "GitHub-Zugang von diesem Mac entfernt."
        } catch { status = safeMessage(error) }
    }
    func checkIfDue() async {
        if let date = UserDefaults.standard.object(forKey: lastAttemptKey) as? Date,
           Date().timeIntervalSince(date) < 24 * 60 * 60 { return }
        await check()
    }
    func check() async {
        guard !busy else { return }
        restore()
        guard let token else { status = "Bitte zuerst GitHub verbinden."; return }
        busy = true; available = nil; status = "Private Builds werden geprüft …"
        defer { busy = false }
        UserDefaults.standard.set(Date(), forKey: lastAttemptKey)
        do { update(try await PrivateUpdateAPI(token: token).latest()) }
        catch { status = safeMessage(error) }
    }
    func install(using installer: AppUpdateInstaller, model: AppModel) async {
        guard !busy, let token, let available else { return }
        busy = true; defer { busy = false }
        await installer.installPrivate(available, token: token, model: model)
    }
    private func update(_ latest: PrivateUpdateArtifact?) {
        guard let latest, let build = latest.build else {
            status = "Noch kein direkt installierbares privates Update vorhanden. DMG-Downloads bleiben über GitHub verfügbar."; return
        }
        if installedBuild > 0 && build > installedBuild {
            available = latest; status = "Private Beta Build \(build) ist verfügbar."
        } else { available = nil; status = "Deine private Beta ist aktuell. Neuester Build: \(build)." }
    }
    private func safeMessage(_ error: Error) -> String {
        (error as NSError).domain == "Stratovo.PrivateUpdates" ? error.localizedDescription
            : "GitHub-Abfrage fehlgeschlagen. Prüfe die Internetverbindung und versuche es erneut."
    }
}
