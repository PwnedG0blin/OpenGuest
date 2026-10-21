import SwiftUI
import StratovoCore

enum MidnightPalette {
    static let navy = Color(red: 0.027, green: 0.082, blue: 0.149)
    static let turquoise = Color(red: 0.212, green: 0.871, blue: 0.820)
    static let violet = Color(red: 0.514, green: 0.455, blue: 0.961)
    static let card = Color(red: 0.073, green: 0.125, blue: 0.196)
}

struct WorkspaceCardSurface: View {
    @AppStorage(WorkspaceAppearance.preferenceKey) private var appearance = WorkspaceAppearance.automatic
    var body: some View {
        Group {
            if appearance == .classic { Color(nsColor: .controlBackgroundColor) }
            else {
                LinearGradient(colors: [MidnightPalette.card, MidnightPalette.navy],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

struct MidnightLaunchButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.45))
            .background(MidnightPalette.turquoise.opacity(configuration.isPressed ? 0.23 : 0.09),
                        in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(MidnightPalette.turquoise.opacity(enabled ? 0.32 : 0.12)))
            .contentShape(RoundedRectangle(cornerRadius: 13))
    }
}

enum WorkspaceAppearance: String, CaseIterable, Identifiable {
    case automatic, glass, classic
    static let preferenceKey = "Stratovo.interfaceAppearance"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return L10n.text("Automatisch")
        case .glass: return "Liquid Glass"
        case .classic: return L10n.text("Klassisch")
        }
    }
    static var supportsGlass: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }
}

/// App chrome only: guest pixels and content cards keep their own rendering.
struct WorkspaceChromeSurface: ViewModifier {
    @AppStorage(WorkspaceAppearance.preferenceKey) private var appearance = WorkspaceAppearance.automatic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var cornerRadius: CGFloat = 16
    var selected = false
    init(cornerRadius: CGFloat = 16, selected: Bool = false) {
        self.cornerRadius = cornerRadius
        self.selected = selected
    }
    private var useGlass: Bool {
        appearance != .classic && !reduceTransparency && contrast != .increased
    }
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), useGlass {
            content.glassEffect(.regular.tint(selected ? MidnightPalette.turquoise.opacity(0.23) : MidnightPalette.navy.opacity(0.30)),
                                in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.34), .cyan.opacity(0.20), MidnightPalette.violet.opacity(0.40)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        } else {
            content.background(selected ? Color.teal.opacity(0.24) : appearance == .classic ? Color(nsColor: .controlBackgroundColor) : MidnightPalette.card,
                               in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.primary.opacity(0.07)))
        }
    }
}

struct WorkspaceActionStyle: ViewModifier {
    @AppStorage(WorkspaceAppearance.preferenceKey) private var appearance = WorkspaceAppearance.automatic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), appearance != .classic,
           !reduceTransparency, contrast != .increased {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

struct WorkspaceAppearanceSettings: View {
    @AppStorage(WorkspaceAppearance.preferenceKey) private var appearance = WorkspaceAppearance.automatic
    var body: some View {
        WorkspaceCard {
            Label(L10n.text("Darstellung"), systemImage: "paintpalette").font(.title2.bold())
            Picker(L10n.text("Bedienelemente"), selection: $appearance) {
                ForEach(WorkspaceAppearance.allCases) { option in
                    Text(option.title).tag(option)
                        .disabled(option == .glass && !WorkspaceAppearance.supportsGlass)
                }
            }.pickerStyle(.segmented)
            HStack(spacing: 12) {
                Label("Windows", systemImage: "desktopcomputer")
                Label("Android", systemImage: "apps.iphone")
                Label("Ubuntu", systemImage: "terminal")
            }.font(.callout).padding(14).modifier(WorkspaceChromeSurface())
                .accessibilityLabel(L10n.text("Vorschau der Darstellung"))
            Text(L10n.text("Gilt sofort für Navigation und Bedienelemente. Deine Auswahl wird gespeichert."))
                .font(.callout).foregroundStyle(.secondary)
            if !WorkspaceAppearance.supportsGlass {
                Text(L10n.text("Liquid Glass benötigt macOS 26 oder neuer. Auf diesem Mac wird die klassische Darstellung verwendet."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ContextHelpButton("Darstellung und Bedienungshilfen") {
                Text(L10n.text("Automatisch verwendet Liquid Glass auf unterstützten macOS-Versionen. Klassisch zeigt feste Flächen. Reduzierte Transparenz und erhöhter Kontrast haben Vorrang. Die Darstellung der Gastsysteme und ihre Grafikleistung werden durch diese Auswahl nicht geändert."))
            }
        }
    }
}

/// Static color behind the native material makes refraction visible without
/// adding animation or affecting guest rendering. Classic stays fully solid.
struct WorkspaceBackdrop: View {
    @AppStorage(WorkspaceAppearance.preferenceKey) private var appearance = WorkspaceAppearance.automatic
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    private var useColor: Bool {
        WorkspaceAppearance.supportsGlass && appearance != .classic && !reduceTransparency && contrast != .increased
    }
    var body: some View {
        ZStack {
            if appearance == .classic { Color(nsColor: .windowBackgroundColor) }
            else { MidnightPalette.navy }
            if useColor {
                LinearGradient(colors: [.cyan.opacity(0.14), .blue.opacity(0.03), MidnightPalette.violet.opacity(0.13)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [MidnightPalette.turquoise.opacity(0.35), .clear],
                               center: UnitPoint(x: 0.02, y: 0.42), startRadius: 0, endRadius: 400)
                RadialGradient(colors: [MidnightPalette.violet.opacity(0.43), .clear],
                               center: UnitPoint(x: 0.12, y: 1), startRadius: 0, endRadius: 400)
                GeometryReader { proxy in
                    Path { path in
                        path.move(to: CGPoint(x: -100, y: proxy.size.height * 0.22))
                        path.addCurve(to: CGPoint(x: proxy.size.width * 0.30, y: -90),
                                      control1: CGPoint(x: 180, y: proxy.size.height * 0.48),
                                      control2: CGPoint(x: -70, y: 0))
                    }.stroke(LinearGradient(colors: [.cyan.opacity(0.30), .blue.opacity(0.03)],
                                            startPoint: .leading, endPoint: .trailing), lineWidth: 90)
                        .blur(radius: 14)
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
