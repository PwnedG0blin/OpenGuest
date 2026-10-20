import AppKit
import Foundation
import SwiftUI
import StratovoCore

@MainActor
final class UbuntuController: ObservableObject {
    @Published private(set) var downloading = false
    @Published private(set) var isoReady = false
    @Published private(set) var diskReady = false
    @Published private(set) var status = "Ubuntu noch nicht eingerichtet"

    func refresh(model: AppModel) {
        guard let root = model.storage?.url.appendingPathComponent("Ubuntu") else { return }
        isoReady = FileManager.default.fileExists(atPath: root.appendingPathComponent("ubuntu-26.04.1-desktop-arm64.iso").path)
        diskReady = FileManager.default.fileExists(atPath: root.appendingPathComponent("ubuntu.qcow2").path)
    }
    func download(model: AppModel) {
        guard !model.running, !model.busy, !downloading, let storage = model.storage,
              let helper = Bundle.main.resourceURL?.appendingPathComponent("GraphicsLab/ubuntu_vm.py") else { return }
        downloading = true; model.setGraphicsLabBusy(true)
        status = L10n.text("Ubuntu 26.04.1 LTS ARM64 wird geladen und geprüft …")
        Task {
            defer { downloading = false; model.setGraphicsLabBusy(false); refresh(model: model) }
            do {
                try storage.validate()
                let config = try Self.configuration(storage: storage)
                let result = try await Task.detached {
                    try CommandCapture.run(CommandSpec(executable: "/usr/bin/python3", arguments: [helper.path,
                        "--config", config.path, "download"]), timeout: 7200)
                }.value
                guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
                status = L10n.text("Ubuntu geladen und SHA-256-geprüft · jetzt installieren")
            } catch { status = error.localizedDescription }
        }
    }
    static func configuration(storage: GuestStorage, extra: [String: Any] = [:]) throws -> URL {
        let root = storage.url.appendingPathComponent("Ubuntu")
        guard root.standardizedFileURL == root.resolvingSymlinksInPath() else { throw GuestError.invalidResources }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = root.appendingPathComponent("config.json")
        guard ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.type] as? FileAttributeType) != .typeSymbolicLink else { throw GuestError.invalidResources }
        let data = ["root": storage.root, "storageID": storage.id] as [String: Any]
        try JSONSerialization.data(withJSONObject: data.merging(extra) { _, new in new }).write(to: file, options: .atomic)
        return file
    }
}

@MainActor
struct UbuntuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: UbuntuController
    @AppStorage("Stratovo.ubuntu.memoryMiB") private var memory = 6144
    @AppStorage("Stratovo.ubuntu.cores") private var cores = 4
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                Label("Ubuntu 26.04.1 LTS · ARM64", systemImage: "terminal").font(.title2.bold())
                Text(L10n.text("Linux als eigenes System im Stratovo-Player. Windows und Android werden nicht verändert."))
                Text(L10n.text("64 GiB virtuelle Festplatte · Empfehlung: 80 GiB freier SSD-Platz. Für die Installation mindestens 40 GiB frei halten. 6–8 GiB RAM; jeweils ein System starten."))
                Picker("RAM", selection: $memory) { Text("6 GiB").tag(6144); Text("8 GiB").tag(8192) }
                Stepper("CPU: \(cores)", value: $cores, in: 2...8)
                Button(L10n.text("1 · Ubuntu ARM herunterladen")) { controller.download(model: model) }
                    .disabled(model.running || model.busy || !model.storageReady || controller.isoReady)
                Button(L10n.text("2 · Ubuntu installieren")) { model.startUbuntu(installing: true, memory: memory, cores: cores) }
                    .disabled(model.running || model.busy || !controller.isoReady)
                Button(L10n.text("Ubuntu starten")) { model.startUbuntu(installing: false, memory: memory, cores: cores) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(model.running || model.busy || !controller.diskReady)
                Text(L10n.text("Im Installer die virtuelle 64-GiB-Festplatte auswählen. Nach der Installation herunterfahren und hier Ubuntu starten wählen; dann wird die ISO nicht erneut eingelegt."))
                    .font(.callout)
                if controller.downloading { ProgressView() }
                Text(controller.status).textSelection(.enabled)
                if model.activeGuest == "ubuntu" && model.running {
                    HStack {
                        Button(L10n.text("Player öffnen")) { model.showPlayer(kind: "ubuntu") }
                        Button(L10n.text("Herunterfahren"), action: model.shutdownGuest)
                    }
                }
                Link("Ubuntu ↗", destination: URL(string: "https://ubuntu.com/download/desktop")!)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }.onAppear { controller.refresh(model: model) }
         .onChange(of: model.running) { _ in controller.refresh(model: model) }
    }
}
