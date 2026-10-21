import AppKit
import SwiftUI
import StratovoCore

/// Bundled, static illustrations: no networking or per-frame work during VM use.
struct GuestSystemArtwork: View {
    let kind: String
    private var artwork: NSImage? {
        guard let url = WorkspaceArtwork.url(for: kind) else { return nil }
        return NSImage(contentsOf: url)
    }
    var body: some View {
        GeometryReader { geometry in
            if let artwork {
                Image(nsImage: artwork).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                LinearGradient(colors: [MidnightPalette.navy, MidnightPalette.violet.opacity(0.4)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }.accessibilityHidden(true)
    }
}

/// Small code-drawn system marks stay crisp at every backing scale.
struct GuestSystemSymbol: View {
    let kind: String
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Canvas { context, _ in
                let rect = CGRect(x: 0, y: 0, width: side, height: side)
                if kind == "windows" {
                    let gap = side * 0.065, half = (side - gap) / 2
                    for y in [CGFloat(0), half + gap] {
                        for x in [CGFloat(0), half + gap] {
                            context.fill(Path(CGRect(x: x, y: y, width: half, height: half)), with: .color(Color(red: 0.10, green: 0.74, blue: 0.94)))
                        }
                    }
                } else if kind == "android" {
                    let green = Color(red: 0.52, green: 0.88, blue: 0.34)
                    let head = CGRect(x: side * 0.1, y: side * 0.24, width: side * 0.8, height: side * 0.65)
                    context.fill(Path(roundedRect: head, cornerRadius: side * 0.29), with: .color(green))
                    for x in [CGFloat(0.30), CGFloat(0.70)] {
                        context.fill(Path(ellipseIn: CGRect(x: side * x - side * 0.045, y: side * 0.47, width: side * 0.09, height: side * 0.09)), with: .color(MidnightPalette.navy))
                        var antenna = Path()
                        antenna.move(to: CGPoint(x: side * x, y: side * 0.31))
                        antenna.addLine(to: CGPoint(x: side * (x < 0.5 ? 0.19 : 0.81), y: side * 0.08))
                        context.stroke(antenna, with: .color(green), style: StrokeStyle(lineWidth: side * 0.055, lineCap: .round))
                    }
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.94, green: 0.32, blue: 0.11)))
                    let ring = rect.insetBy(dx: side * 0.25, dy: side * 0.25)
                    context.stroke(Path(ellipseIn: ring), with: .color(.white), lineWidth: side * 0.085)
                    for angle in [Double(0), 2 * Double.pi / 3, 4 * Double.pi / 3] {
                        let dot = CGPoint(x: side * 0.5 + CGFloat(cos(angle)) * side * 0.29,
                                          y: side * 0.5 + CGFloat(sin(angle)) * side * 0.29)
                        let circle = CGRect(x: dot.x - side * 0.09, y: dot.y - side * 0.09, width: side * 0.18, height: side * 0.18)
                        context.fill(Path(ellipseIn: circle.insetBy(dx: -side * 0.04, dy: -side * 0.04)), with: .color(Color(red: 0.94, green: 0.32, blue: 0.11)))
                        context.fill(Path(ellipseIn: circle), with: .color(.white))
                    }
                }
            }.frame(width: side, height: side)
        }.accessibilityHidden(true)
    }
}

struct StratovoBrandMark: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let w = proxy.size.width, h = proxy.size.height
                path.move(to: CGPoint(x: w * 0.88, y: h * 0.06))
                path.addCurve(to: CGPoint(x: w * 0.18, y: h * 0.37), control1: CGPoint(x: w * 1.04, y: h * 0.27), control2: CGPoint(x: w * 0.10, y: h * 0.18))
                path.addCurve(to: CGPoint(x: w * 0.81, y: h * 0.64), control1: CGPoint(x: w * 0.05, y: h * 0.52), control2: CGPoint(x: w * 0.98, y: h * 0.48))
                path.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.94), control1: CGPoint(x: w * 0.75, y: h * 0.80), control2: CGPoint(x: w * 0.02, y: h * 0.75))
            }
            .stroke(LinearGradient(colors: [MidnightPalette.turquoise, MidnightPalette.violet, .cyan],
                                   startPoint: .topTrailing, endPoint: .bottomLeading),
                    style: StrokeStyle(lineWidth: proxy.size.width * 0.31, lineCap: .butt, lineJoin: .round))
        }
    }
}
