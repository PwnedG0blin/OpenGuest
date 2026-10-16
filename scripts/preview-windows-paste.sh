#!/bin/bash
# Render production paste/credit views for visual review, with an in-memory model.
# Does not open a VM, read the clipboard, or access saved settings/accounts.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$project_dir"
preview_dir="${1:-$project_dir/dist/paste-preview}"
mkdir -p "$preview_dir"
preview_dir="$(cd -- "$preview_dir" && pwd)"
preview_tmp="$(mktemp -d)"
trap 'rm -rf "$preview_tmp"' EXIT
binary_dir="$(xcrun swift build --show-bin-path)"
cat > "$preview_tmp/Preview.swift" <<'SWIFT'
import AppKit
import SwiftUI
import OpenGuestCore

@MainActor
final class AppModel: ObservableObject {
    @Published var windowsTextLayout: WindowsTextLayout = .german
    let running = true
    let windowsPasteBusy = false
    @Published var androidCustomDisplay = true
    @Published var androidDisplayWidth = "1200"
    @Published var androidDisplayHeight = "1920"
    @Published var androidDisplayDensity = "320"
    let canEditAndroidDisplay = true
    let canApplyAndroidDisplay = true
    let androidDisplayBusy = false
    let androidDisplayIssue: String? = nil
    let androidDisplayStatus = "Android: 1200 × 1920 · 320 dpi · eigene Anzeige"
    func applyAndroidDisplayNow() async { }
    func restoreAndroidDisplay() async { }
    func selectGalaxyS26UltraDisplay() { }
    func fitAndroidPlayerWindow() { }
    func pasteWindowsText(_ input: WindowsTextInput) { }
    let androidPasteStatus = ""
    func pasteAndroidText(_ input: AndroidClipboardText) async -> Bool { true }
}

@main
@MainActor
struct PastePreview {
    static func render<V: View>(_ root: V, size: NSSize, appearance: NSAppearance, to file: URL) throws {
        let view = NSHostingView(rootView: root)
        view.appearance = appearance
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        window.contentView = view
        window.orderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "PastePreview", code: 1)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "PastePreview", code: 2)
        }
        try png.write(to: file)
        print("Rendered \(file.lastPathComponent): \(bitmap.pixelsWide)×\(bitmap.pixelsHigh)")
        window.orderOut(nil)
        window.close()
    }

    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let examples = [
            ("command", #"reg query HKLM\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot /v CloudAssignedTenantDomain"#),
            ("empty", ""),
            ("multiline", "Erste Zeile\nZweite Zeile")
        ]
        for dark in [false, true] {
            let scheme: ColorScheme = dark ? .dark : .light
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            app.appearance = appearance
            for (name, text) in examples {
                let model = AppModel()
                let view = WindowsPasteSheet(model: model, text: .constant(text)).environment(\.colorScheme, scheme)
                let filename = "paste-\(name)-\(dark ? "dark" : "light").png"
                try render(view, size: NSSize(width: 600, height: 680), appearance: appearance,
                           to: directory.appendingPathComponent(filename))
            }
            for (name, text) in [("unicode", "Grüße vom Mac 👋 · @PwnedG0blin"), ("empty", ""), ("multiline", "Erste Zeile\nZweite Zeile")] {
                try render(AndroidPasteSheet(model: AppModel(), text: .constant(text)).environment(\.colorScheme, scheme),
                    size: NSSize(width: 560, height: 560), appearance: appearance,
                    to: directory.appendingPathComponent("android-paste-\(name)-\(dark ? "dark" : "light").png"))
            }
            let credits = DeveloperCredits().padding(20).frame(width: 214)
                .background(Color(nsColor: .controlBackgroundColor)).environment(\.colorScheme, scheme)
            try render(credits, size: NSSize(width: 214, height: 250), appearance: appearance,
                       to: directory.appendingPathComponent("credits-\(dark ? "dark" : "light").png"))
            try render(AndroidDisplaySheet(model: AppModel()).environment(\.colorScheme, scheme),
                       size: NSSize(width: 500, height: 520), appearance: appearance,
                       to: directory.appendingPathComponent("android-display-\(dark ? "dark" : "light").png"))
            let image = NSImage(size: NSSize(width: 1000, height: 600), flipped: false) { rect in
                NSColor.systemTeal.setFill(); rect.fill()
                NSColor.systemIndigo.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 300).fill()
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 48), .foregroundColor: NSColor.white]
                ("OBEN · Pixelkoje" as NSString).draw(at: NSPoint(x: 30, y: 520), withAttributes: attributes)
                ("UNTEN · Beispielbild" as NSString).draw(at: NSPoint(x: 30, y: 30), withAttributes: attributes)
                return true
            }
            for zoom in [Double?.none, Double?(200)] {
                let surface = PlayerSurface(image: image, videoLayer: nil, sourceSize: CGSize(width: 1000, height: 600),
                    pointer: { _,_,_ in }, key: { _,_,_ in }, zoomPercent: zoom)
                try render(surface, size: NSSize(width: 600, height: 500), appearance: appearance,
                    to: directory.appendingPathComponent("viewport-\(zoom == nil ? "fit" : "zoom")-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
SWIFT
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" -I "$binary_dir/Modules" \
    Sources/OpenGuest/WindowsPasteSheet.swift Sources/OpenGuest/DeveloperCredits.swift \
    Sources/OpenGuest/AndroidDisplaySheet.swift Sources/OpenGuest/AndroidPasteSheet.swift Sources/OpenGuest/PlayerSurface.swift "$preview_tmp/Preview.swift" \
    "$binary_dir"/OpenGuestCore.build/*.o -o "$preview_tmp/render-paste"
"$preview_tmp/render-paste" "$preview_dir"
