import AppKit
import SwiftUI
import StratovoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        WorkspaceAppearance.applyApplicationAppearance(WorkspaceAppearance(rawValue:
            UserDefaults.standard.string(forKey: WorkspaceAppearance.preferenceKey) ?? "automatic") ?? .automatic)
        if let url = Bundle.main.url(forResource: "Stratovo", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model?.running == true {
            let alert = NSAlert()
            alert.messageText = L10n.text("Ein Gastprozess läuft noch")
            alert.informativeText = L10n.text("Fahre das Gastsystem zuerst herunter, damit seine Daten sauber gespeichert werden. Danach kannst du Stratovo schließen.")
            alert.addButton(withTitle: L10n.text("Gast herunterfahren"))
            alert.addButton(withTitle: L10n.text("Zurück"))
            if alert.runModal() == .alertFirstButtonReturn { model?.shutdownGuest() }
            return .terminateCancel
        }
        if model?.busy == true {
            let alert = NSAlert()
            alert.messageText = L10n.text("Aktion läuft noch")
            alert.informativeText = L10n.text("Warte, bis die laufende Einrichtung oder Dateiaktion abgeschlossen ist. Danach kannst du Stratovo schließen.")
            alert.addButton(withTitle: L10n.text("Zurück"))
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
}

@main
@MainActor
struct StratovoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = "system"
    @AppStorage(WorkspaceAppearance.preferenceKey) private var interfaceAppearance = WorkspaceAppearance.automatic

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .environment(\.locale, Locale(identifier: L10n.resolve(preference: interfaceLanguage, preferredLanguages: Locale.preferredLanguages)))
                .environment(\.layoutDirection, L10n.code == "ar" ? .rightToLeft : .leftToRight)
                .onChange(of: interfaceAppearance) { _, value in WorkspaceAppearance.applyApplicationAppearance(value) }
                .task {
                    WorkspaceAppearance.applyApplicationAppearance(interfaceAppearance)
                    delegate.model = model
                    await model.open()
                }
        }
        .defaultSize(width: 1240, height: 850)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) {
                Link(L10n.text("Android-Geräte anlegen"), destination: URL(string: "https://developer.android.com/studio/run/managing-avds")!)
                Link(L10n.text("Windows Arm64 herunterladen"), destination: URL(string: "https://www.microsoft.com/de-de/software-download/windows11arm64")!)
            }
        }
    }
}
