import SwiftUI
import StratovoCore

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var selection: WorkspaceTab = .dashboard
    @State private var showDiagnostics = false
    @AppStorage(WorkspaceAppearance.preferenceKey) private var appearance = WorkspaceAppearance.automatic

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 230)
                .modifier(WorkspaceChromeSurface(cornerRadius: 0))
                .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.13)).frame(width: 1) }
            VStack(spacing: 0) {
                header.padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 20)
                QuickLaunchBar(model: model) { selection = $0 }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !model.supportedHost || !model.hypervisorAvailable {
                            WorkspaceNotice(L10n.text("Apple Silicon und Hardwarevirtualisierung benötigt"),
                                L10n.text("Starte die native ARM64-Version auf einem Mac mit M-Chip. Intel-Macs und Rosetta werden nicht unterstützt."))
                        }
                        if !model.storageReady && model.storage != nil {
                            WorkspaceNotice(L10n.text("Datenordner nicht erreichbar"),
                                L10n.text("Bitte die gewählte SSD anschließen. Android, Windows und Downloads bleiben bis dahin gesperrt."))
                        }
                        workspace
                    }.padding(28).frame(maxWidth: 1180, alignment: .leading).frame(maxWidth: .infinity)
                }
                if model.running { sessionBar }
            }
        }
        .background { WorkspaceBackdrop() }
        .preferredColorScheme(appearance == .classic ? nil : .dark)
        .frame(minWidth: 860, minHeight: 650).tint(MidnightPalette.turquoise)
        .onChange(of: model.settings.iso) { _, _ in model.refreshWindowsISO() }
        .sheet(isPresented: $model.showStorageSetup) { StorageSetupSheet(model: model).interactiveDismissDisabled() }
        .sheet(isPresented: $showDiagnostics) { SessionDiagnosticsView(model: model) }
        .alert("Stratovo", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    @ViewBuilder private var workspace: some View {
        switch selection {
        case .dashboard: DashboardView(model: model) { selection = $0 }
        case .updates: GitHubUpdatesView(model: model)
        case .android: AndroidWorkspaceView(model: model)
        case .windows: WindowsWorkspaceView(model: model)
        case .ubuntu: UbuntuView(model: model, controller: model.ubuntu)
        case .exchange: ExchangeFolderView(model: model, controller: model.exchange)
        case .setup: SetupWorkspaceView(model: model)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                StratovoBrandMark().frame(width: 32, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stratovo").font(.system(size: 25, weight: .bold))
                    Text(AppPresentation.releaseLabel).font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 28)
            ScrollView {
                VStack(spacing: 9) {
                    ForEach([WorkspaceTab.dashboard, .windows, .android, .ubuntu, .exchange, .updates, .setup]) { tab in
                        navigationButton(tab)
                    }
                }.padding(.horizontal, 12)
            }
            Divider().padding(.horizontal, 22).padding(.top, 12)
            DeveloperCredits().padding(.horizontal, 22).padding(.vertical, 18)
        }
    }

    private func navigationButton(_ tab: WorkspaceTab) -> some View {
        Button { selection = tab } label: {
            HStack(spacing: 13) {
                if tab == .windows || tab == .android || tab == .ubuntu {
                    GuestSystemSymbol(kind: tab == .windows ? "windows" : tab == .android ? "android" : "ubuntu")
                        .frame(width: 23, height: 23)
                } else {
                    Image(systemName: tab.icon).font(.system(size: 20, weight: .medium)).frame(width: 23)
                }
                Text(tab.title).font(.system(size: 15, weight: selection == tab ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 17).padding(.vertical, 14)
            .foregroundStyle(selection == tab ? Color.white : Color.primary.opacity(0.86))
            .background {
                if selection == tab { Color.clear.modifier(WorkspaceChromeSurface(cornerRadius: 11, selected: true)) }
            }
            .overlay(alignment: .leading) {
                if selection == tab { Capsule().fill(MidnightPalette.turquoise).frame(width: 4).padding(.vertical, 8) }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain).accessibilityAddTraits(selection == tab ? [.isSelected] : [])
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(selection == .dashboard ? L10n.text("Deine Systeme") : selection.title)
                    .font(.system(size: 34, weight: .bold))
                Text(L10n.text(selection == .dashboard ? "Alles bereit für deinen nächsten Start." : selection.subtitle))
                    .font(.system(size: 16)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            WorkspaceUtilityBar(tab: selection, busy: model.busy, canRefresh: !model.running,
                                diagnose: { showDiagnostics = true }, refresh: { await model.refresh() })
                .padding(.top, 5)
        }
    }

    private var sessionBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.green)
            Text(model.sessionName).font(.callout.weight(.medium)).lineLimit(1)
            Spacer()
            if !model.activeGuest.isEmpty {
                Button(L10n.text("Player öffnen")) { model.showPlayer(kind: model.activeGuest) }
            }
            Button(L10n.text("Herunterfahren"), action: model.shutdownGuest)
        }.padding(.horizontal, 18).padding(.vertical, 12)
            .modifier(WorkspaceChromeSurface()).padding(.horizontal, 20).padding(.bottom, 12)
    }
}

enum AppPresentation {
    static var releaseLabel: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info["CFBundleVersion"] as? String ?? "dev"
        let flavor = info["StratovoBuildFlavor"] as? String == "private" ? "Private Beta 7" : "Beta 7"
        return "\(version) · \(flavor) · \(build)"
    }
}
