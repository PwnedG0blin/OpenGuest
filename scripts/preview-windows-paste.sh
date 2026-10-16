#!/bin/bash
# Render the production paste view for visual review, with an in-memory model.
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
                let view = NSHostingView(rootView: WindowsPasteSheet(model: model, text: .constant(text)).environment(\.colorScheme, scheme))
                view.appearance = appearance
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 680),
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
                let filename = "paste-\(name)-\(dark ? "dark" : "light").png"
                try png.write(to: directory.appendingPathComponent(filename))
                print("Rendered \(filename): \(bitmap.pixelsWide)×\(bitmap.pixelsHigh)")
                window.orderOut(nil)
                window.close()
            }
        }
    }
}
SWIFT
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" -I "$binary_dir/Modules" \
    Sources/OpenGuest/WindowsPasteSheet.swift "$preview_tmp/Preview.swift" \
    "$binary_dir"/OpenGuestCore.build/*.o -o "$preview_tmp/render-paste"
"$preview_tmp/render-paste" "$preview_dir"
