import SwiftUI
import StratovoCore

@MainActor
struct StorageSetupSheet: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L10n.text("Wo sollen deine Systeme gespeichert werden?"), systemImage: "externaldrive.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.text("Wähle ein Laufwerk oder einen Ordner. Stratovo erstellt dort einen eigenen Ordner „Stratovo“ für Android, Windows und die benötigten Dateien."))
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    StorageBudgetView(windowsGiB: model.windowsCapacityGiB ?? 80)
                    Text(L10n.text("Vorhandene Daten werden kopiert und vollständig geprüft. Die Originale bleiben zunächst als Sicherung auf der internen Festplatte. Nach dem erfolgreichen Test kannst du diese Sicherungen in der App entfernen."))
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    Label(L10n.text("Vorher Android und Windows herunterfahren und Android Studio beenden."), systemImage: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("Dein Datenordner")).font(.system(size: 16, weight: .bold))
                        Text(model.proposedStoragePath.isEmpty ? L10n.text("Noch kein Ziel ausgewählt") : model.proposedStoragePath)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(L10n.text("SSD oder Ordner wählen …"), action: model.chooseStorageFolder)
                            .font(.system(size: 15, weight: .semibold)).controlSize(.large).disabled(model.busy)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.errorMessage == nil ? "Status" : "Umzug angehalten",
                              systemImage: model.errorMessage == nil ? "info.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text(model.storageStatus).font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if model.busy { ProgressView().controlSize(.regular) }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background((model.errorMessage == nil ? Color.teal : Color.orange).opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder((model.errorMessage == nil ? Color.teal : Color.orange).opacity(0.65)))
                }.padding(.trailing, 8)
            }
            Divider()
            Text(L10n.text("Kleine Einstellungen und macOS-Auslagerungsdateien können intern bleiben."))
                .font(.system(size: 14)).foregroundStyle(.primary)
            HStack {
                Spacer()
                Button(L10n.text("Speicherort einrichten und Daten übernehmen"), action: model.configureStorage)
                    .font(.system(size: 16, weight: .semibold))
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(model.proposedStoragePath.isEmpty || model.busy)
            }
        }.padding(28).frame(minWidth: 600, idealWidth: 720, maxWidth: 820, minHeight: 500, idealHeight: 620)
    }

}
