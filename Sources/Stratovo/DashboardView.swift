import SwiftUI
import StratovoCore

@MainActor
struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var graphicsLab: WindowsGraphicsLabController
    @ObservedObject private var ubuntu: UbuntuController
    var navigate: (WorkspaceTab) -> Void

    init(model: AppModel, navigate: @escaping (WorkspaceTab) -> Void) {
        self.model = model
        self.graphicsLab = model.graphicsLab
        self.ubuntu = model.ubuntu
        self.navigate = navigate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), alignment: .top)], spacing: 16) {
                system("Windows 11", kind: "windows", ready: graphicsLab.runtimeReady && model.windowsDiskBytes != nil,
                       running: model.running && model.activeGuest == "windows", tab: .windows)
                system("Android", kind: "android", ready: model.androidReady,
                       running: model.running && model.activeGuest == "android", tab: .android)
                system("Ubuntu", kind: "ubuntu", ready: ubuntu.diskReady,
                       running: model.running && model.activeGuest == "ubuntu", tab: .ubuntu)
            }
            WorkspaceCard {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { storageSummary; Spacer(minLength: 10); storageButton }
                    VStack(alignment: .leading, spacing: 16) { storageSummary; storageButton }
                }
            }
        }
        .onAppear { graphicsLab.refresh(model: model); ubuntu.refresh(model: model) }
    }

    private var storageSummary: some View {
        HStack(spacing: 17) {
            Image(systemName: "externaldrive").font(.system(size: 28)).frame(width: 54, height: 54)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Dein Speicher")).font(.headline)
                HStack(spacing: 8) {
                    Circle().fill(model.storageReady ? Color.green : Color.orange).frame(width: 9, height: 9)
                    Text(L10n.text(model.storageReady ? "Datenordner verbunden" : "Speicherort auswählen"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                if let storage = model.storage {
                    Text(storage.root).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).help(storage.root)
                }
            }
        }
    }

    private var storageButton: some View {
        Button {
            if model.storage == nil { model.showStorageSetup = true } else { navigate(.setup) }
        } label: {
            HStack(spacing: 12) { Text(L10n.text("Speicher verwalten")); Image(systemName: "chevron.right") }
                .padding(.horizontal, 10).padding(.vertical, 7)
        }.modifier(WorkspaceActionStyle()).disabled(model.busy || model.running)
    }

    private func system(_ title: String, kind: String, ready: Bool, running: Bool, tab: WorkspaceTab) -> some View {
        VStack(spacing: 0) {
            GuestSystemArtwork(kind: kind).frame(height: 158).clipped()
                .onTapGesture { navigate(tab) }
                .accessibilityHidden(true)
            HStack(alignment: .center, spacing: 13) {
                GuestSystemSymbol(kind: kind).frame(width: 29, height: 29)
                Button { navigate(tab) } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                        HStack(spacing: 7) {
                            Circle().fill(running || ready ? Color.green : Color.orange).frame(width: 8, height: 8)
                            Text(L10n.text(running ? "Läuft" : ready ? "Bereit" : "Einrichtung nötig"))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Menu {
                    Button(L10n.text("Öffnen")) { navigate(tab) }
                    if running {
                        Button(L10n.text("Player öffnen")) { model.showPlayer(kind: kind) }
                        Button(L10n.text("Herunterfahren"), action: model.shutdownGuest)
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.headline).frame(width: 30, height: 30)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .padding(3).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(L10n.text("Optionen") + " · " + title)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { WorkspaceCardSurface() }
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.white.opacity(0.13)))
        .accessibilityElement(children: .contain)
    }
}
