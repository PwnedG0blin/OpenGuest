import SwiftUI
import StratovoCore

/// Stable click targets and labels for the three workspace utilities.
@MainActor
struct WorkspaceUtilityBar: View {
    let tab: WorkspaceTab
    let busy: Bool
    let canRefresh: Bool
    let diagnose: () -> Void
    let refresh: () async -> Void
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 3) {
            Button { showHelp = true } label: {
                Label(L10n.text("Hilfe und Anleitung"), systemImage: "questionmark.circle")
            }.help(L10n.text("Hilfe und Anleitung"))
            separator
            Button(action: diagnose) {
                Label(L10n.text("Diagnose"), systemImage: "waveform.path.ecg")
            }.help(L10n.text("Protokolle und Diagnose öffnen"))
            separator
            Button { Task { await refresh() } } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise").opacity(busy ? 0 : 1)
                    if busy { ProgressView().controlSize(.small) }
                }.accessibilityLabel(L10n.text(busy ? "Aktion läuft" : "System prüfen"))
            }.help(L10n.text("System prüfen")).disabled(!canRefresh || busy)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(WorkspaceUtilityButtonStyle())
        .padding(5)
        .modifier(WorkspaceChromeSurface(cornerRadius: 16))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Hilfe und Systemwerkzeuge"))
        .sheet(isPresented: $showHelp) {
            WorkspaceHelpSheet(title: tab.title) { WorkspaceGuide(tab: tab) }
        }
    }

    private var separator: some View {
        Rectangle().fill(Color.primary.opacity(0.14)).frame(width: 1, height: 16)
            .accessibilityHidden(true)
    }
}

private struct WorkspaceUtilityButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    private var accent: Color {
        colorScheme == .dark ? MidnightPalette.turquoise : Color(red: 0.03, green: 0.43, blue: 0.46)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .frame(width: 36, height: 36)
            .foregroundStyle(enabled ? accent : Color.secondary)
            .background(MidnightPalette.turquoise.opacity(enabled && (hovering || configuration.isPressed) ? 0.14 : 0),
                        in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(
                MidnightPalette.turquoise.opacity(enabled && hovering ? 0.28 : 0)))
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .onHover { hovering = $0 }
    }
}
