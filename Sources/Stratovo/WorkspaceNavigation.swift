import StratovoCore

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case updates = "Updates"
    case android = "Android"
    case windows = "Windows Arm"
    case ubuntu = "Ubuntu ARM"
    case exchange = "Dateiaustausch"
    case setup = "Einrichtung"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: return L10n.text("Übersicht")
        case .windows: return "Windows"
        case .ubuntu: return "Ubuntu"
        case .exchange: return L10n.text("Dateien")
        case .setup: return L10n.text("Einstellungen")
        default: return L10n.text(rawValue)
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .updates: return "arrow.triangle.2.circlepath"
        case .android: return "apps.iphone"
        case .windows: return "desktopcomputer"
        case .ubuntu: return "terminal"
        case .exchange: return "folder.badge.person.crop"
        case .setup: return "slider.horizontal.3"
        }
    }
}
