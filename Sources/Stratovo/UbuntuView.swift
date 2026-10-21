import SwiftUI
import StratovoCore

@MainActor
struct UbuntuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: UbuntuController
    @AppStorage("Stratovo.ubuntu.memoryMiB") private var memory = 6144
    @AppStorage("Stratovo.ubuntu.cores") private var cores = 4
    private var blocked: Bool { model.running || model.busy || !model.storageReady || controller.downloading }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WorkspaceCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Ubuntu", systemImage: "terminal").font(.title2.bold())
                        Text(L10n.text("Dein Linux-Arbeitsplatz auf dem Mac.")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.running && model.activeGuest == "ubuntu" {
                        Button(L10n.text("Player öffnen")) { model.showPlayer(kind: "ubuntu") }
                            .buttonStyle(.borderedProminent)
                        Button(L10n.text("Herunterfahren"), action: model.shutdownGuest)
                    } else {
                        Button(L10n.text("Ubuntu starten")) { model.startUbuntu(installing: false, memory: memory, cores: cores) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(blocked || !controller.diskReady)
                    }
                }
                WorkspaceStatusBadge(controller.diskReady ? L10n.text("Bereit") : L10n.text("Einrichtung nötig"), ready: controller.diskReady)
                if !controller.status.isEmpty { Text(controller.status).font(.callout).textSelection(.enabled) }
                if controller.downloading { ProgressView() }
            }
            if !controller.diskReady {
                installation
            } else {
                DisclosureGroup(L10n.text("Ubuntu einrichten")) { installation.padding(.top, 8) }
            }
            DisclosureGroup(L10n.text("Erweiterte Einstellungen")) {
                WorkspaceCard {
                    Picker("RAM", selection: $memory) { Text("6 GiB").tag(6144); Text("8 GiB").tag(8192) }
                    Stepper("CPU: \(cores)", value: $cores, in: 2...8)
                }.disabled(model.running || model.busy).padding(.top, 8)
            }
        }
        .onAppear { controller.refresh(model: model) }
        .onChange(of: model.running) { _, _ in controller.refresh(model: model) }
    }
    private var installation: some View {
        WorkspaceCard {
            Label(L10n.text("Ubuntu einrichten"), systemImage: "plus.circle").font(.headline)
            Text("Ubuntu 26.04.1 LTS · ARM64").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(L10n.text("1 · Ubuntu ARM herunterladen")) { controller.download(model: model) }
                    .disabled(blocked || controller.isoReady)
                Button(L10n.text("2 · Ubuntu installieren")) { model.startUbuntu(installing: true, memory: memory, cores: cores) }
                    .disabled(blocked || !controller.isoReady)
            }
            ContextHelpButton("Ubuntu installieren") {
                Text(L10n.text("Linux als eigenes System im Stratovo-Player. Windows und Android werden nicht verändert."))
                Text(L10n.text("64 GiB virtuelle Festplatte · Empfehlung: 80 GiB freier SSD-Platz. Für die Installation mindestens 40 GiB frei halten. 6–8 GiB RAM; jeweils ein System starten."))
                Text(L10n.text("Im Installer die virtuelle 64-GiB-Festplatte auswählen. Nach der Installation herunterfahren und hier Ubuntu starten wählen; dann wird die ISO nicht erneut eingelegt."))
                Link("Ubuntu ↗", destination: URL(string: "https://ubuntu.com/download/desktop")!)
            }
        }
    }
}
