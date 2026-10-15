import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model?.running == true {
            let alert = NSAlert()
            alert.messageText = "Ein Gastprozess läuft noch"
            alert.informativeText = "Fahre das Gastsystem zuerst herunter, damit seine Daten sauber gespeichert werden. Danach kannst du OpenGuest schließen."
            alert.addButton(withTitle: "Gast herunterfahren")
            alert.addButton(withTitle: "Zurück")
            if alert.runModal() == .alertFirstButtonReturn { model?.shutdownGuest() }
            return .terminateCancel
        }
        if model?.busy == true { return .terminateCancel }
        return .terminateNow
    }
}

@main
@MainActor
struct OpenGuestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task {
                    delegate.model = model
                    await model.open()
                }
        }
        .defaultSize(width: 1060, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) {
                Link("Android-Geräte anlegen", destination: URL(string: "https://developer.android.com/studio/run/managing-avds")!)
                Link("Windows Arm64 herunterladen", destination: URL(string: "https://www.microsoft.com/de-de/software-download/windows11arm64")!)
            }
        }
    }
}
