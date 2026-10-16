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
    func pasteWindowsText(_ input: WindowsTextInput) { }
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
            let credits = DeveloperCredits().padding(20).frame(width: 214)
                .background(Color(nsColor: .controlBackgroundColor)).environment(\.colorScheme, scheme)
            try render(credits, size: NSSize(width: 214, height: 250), appearance: appearance,
                       to: directory.appendingPathComponent("credits-\(dark ? "dark" : "light").png"))
        }
    }
}
SWIFT
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" -I "$binary_dir/Modules" \
    Sources/OpenGuest/WindowsPasteSheet.swift Sources/OpenGuest/DeveloperCredits.swift "$preview_tmp/Preview.swift" \
    "$binary_dir"/OpenGuestCore.build/*.o -o "$preview_tmp/render-paste"
"$preview_tmp/render-paste" "$preview_dir"
