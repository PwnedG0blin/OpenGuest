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
            Text("Eine Oberfläche. Zwei Engines.\nEntwickelt für Apple Silicon.")
                .foregroundStyle(.secondary)
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text("Entwickelt von").foregroundStyle(.secondary)
                Text("PwnedG0blin").font(.subheadline.weight(.semibold))
            }
            Link("X · @PwnedG0blin ↗", destination: URL(string: "https://x.com/PwnedG0blin")!)
                .foregroundStyle(linkColor)
                .help("X-Profil von PwnedG0blin im Browser öffnen")
            Link("Patreon · Unterstützen ↗", destination: URL(string: "https://www.patreon.com/cw/PwnedG0blinApp")!)
                .foregroundStyle(linkColor)
                .help("PwnedG0blin auf Patreon im Browser öffnen")
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
