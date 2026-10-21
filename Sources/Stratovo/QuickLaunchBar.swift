import SwiftUI
import StratovoCore

/// Always visible above the workspace; uses the same guest actions and guards.
@MainActor
struct QuickLaunchBar: View {
    @ObservedObject var model: AppModel
    var navigate: (WorkspaceTab) -> Void
    @ObservedObject private var graphicsLab: WindowsGraphicsLabController
    @ObservedObject private var ubuntu: UbuntuController
    @AppStorage("Stratovo.ubuntu.memoryMiB") private var memory = 6144
    @AppStorage("Stratovo.ubuntu.cores") private var cores = 4

    init(model: AppModel, navigate: @escaping (WorkspaceTab) -> Void) {
        self.navigate = navigate
        self.model = model
        self.graphicsLab = model.graphicsLab
        self.ubuntu = model.ubuntu
    }

    var body: some View {
        buttons
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WorkspaceChromeSurface(cornerRadius: 20))
        .padding(.horizontal, 28)
        .onAppear { refreshAvailability() }
        .onChange(of: model.storageReady) { _, _ in refreshAvailability() }
        .onChange(of: model.running) { _, _ in refreshAvailability() }
    }

    private var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { launchButtons }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)],
                      alignment: .leading, spacing: 12) { launchButtons }
        }
    }

    @ViewBuilder private var launchButtons: some View {
        launch("Windows starten", guest: "windows", setup: "Windows einrichten", tab: .windows, ready: model.canResumeWindows && graphicsLab.runtimeReady,
               action: model.startExistingWindows)
        launch("Android starten", guest: "android", setup: "Android einrichten", tab: .android, ready: model.canStartAndroid,
               action: model.startAndroid)
        launch("Ubuntu starten", guest: "ubuntu", setup: "Ubuntu einrichten", tab: .ubuntu,
               ready: !model.running && !model.busy && model.storageReady && ubuntu.diskReady && !ubuntu.downloading) {
            model.startUbuntu(installing: false, memory: memory, cores: cores)
        }
    }

    private func launch(_ title: String, guest: String, setup: String, tab: WorkspaceTab, ready: Bool, action: @escaping () -> Void) -> some View {
        let active = model.running && model.activeGuest == guest
        return Button {
            if active { model.showPlayer(kind: guest) }
            else if ready { action() }
            else { navigate(tab) }
        } label: {
            HStack(spacing: 13) {
                GuestSystemSymbol(kind: guest).frame(width: 31, height: 31)
                Text(active ? "\(guest.capitalized) · \(L10n.text("Player öffnen"))" : L10n.text(ready ? title : setup))
                    .font(.system(size: 15, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.callout).foregroundStyle(.secondary)
            }.padding(.horizontal, 15).padding(.vertical, 18).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MidnightLaunchButtonStyle())
        .disabled(!active && (model.running || model.busy))
        .frame(minWidth: 200, maxWidth: .infinity)
    }

    private func refreshAvailability() {
        graphicsLab.refresh(model: model)
        ubuntu.refresh(model: model)
    }
}
