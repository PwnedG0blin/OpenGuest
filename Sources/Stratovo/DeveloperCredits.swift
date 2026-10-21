import StratovoCore
import SwiftUI

@MainActor
struct DeveloperCredits: View {
    @Environment(\.colorScheme) private var colorScheme
    private var linkColor: Color {
        colorScheme == .dark ? Color(red: 0.35, green: 0.82, blue: 0.79) : Color(red: 0.03, green: 0.43, blue: 0.46)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Open Source · MIT", systemImage: "curlybraces")
            Text(L10n.text("Eine Oberfläche. Drei Systeme.\nEntwickelt für Apple Silicon."))
                .foregroundStyle(.secondary)
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("Entwickelt von")).foregroundStyle(.secondary)
                Text("PwnedG0blin").font(.subheadline.weight(.semibold))
            }
            Link("X · @PwnedG0blin ↗", destination: URL(string: "https://x.com/PwnedG0blin")!)
                .foregroundStyle(linkColor)
                .help(L10n.text("X-Profil von PwnedG0blin im Browser öffnen"))
            Link(L10n.text("GitHub Sponsors · Unterstützen ↗"), destination: URL(string: "https://github.com/sponsors/PwnedG0blin")!)
                .foregroundStyle(linkColor)
            Link(L10n.text("Patreon · Unterstützen ↗"), destination: URL(string: "https://www.patreon.com/cw/PwnedG0blinApp")!)
                .foregroundStyle(linkColor)
                .help(L10n.text("PwnedG0blin auf Patreon im Browser öffnen"))
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
