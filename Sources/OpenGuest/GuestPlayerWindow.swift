import AppKit
import SwiftUI
import OpenGuestCore

/// One retained window per player. Closing the display never terminates a guest.
@MainActor
final class GuestPlayerWindows: NSObject, NSWindowDelegate {
    private var windows: [String: NSWindow] = [:]

    func show(kind: String, model: AppModel) {
        guard kind == "android" || kind == "windows" else { return }
        let window: NSWindow
        if let existing = windows[kind] {
            window = existing
        } else {
            let android = kind == "android"
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: android ? 520 : 1100, height: 780),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
            window.title = android ? "Android Player · Pixelkoje" : "Windows Player · Pixelkoje"
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.contentMinSize = NSSize(width: 360, height: 480)
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.delegate = self
            window.contentView = NSHostingView(rootView: GuestPlayerView(model: model, kind: kind))
            window.center()
            window.setFrameAutosaveName("OpenGuest.player.\(kind)")
            windows[kind] = window
        }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func toggleFullScreen(kind: String) { windows[kind]?.toggleFullScreen(nil) }

    func windowWillClose(_ notification: Notification) {
        // Release held guest keys when the display is hidden.
        (notification.object as? NSWindow)?.makeFirstResponder(nil)
    }
}

@MainActor
private struct GuestPlayerView: View {
    @ObservedObject var model: AppModel
    let kind: String
    private var active: Bool { model.activeGuest == kind }
    @State private var pastePresented = false
    @State private var pasteDraft = ""
    @AppStorage private var fitsWindow: Bool
    @AppStorage private var zoomPercent: Double
    @State private var androidDisplayPresented = false
    private var safeZoom: Double { zoomPercent.isFinite ? max(25, min(300, zoomPercent)) : 100 }

    init(model: AppModel, kind: String) {
        self.model = model; self.kind = kind
        _fitsWindow = AppStorage(wrappedValue: true, "Pixelkoje.playerFit.\(kind)")
        _zoomPercent = AppStorage(wrappedValue: 100, "Pixelkoje.playerZoom.\(kind)")
    }

    private func beginPaste() {
        guard active, !model.windowsPasteBusy else { return }
        pasteDraft = NSPasteboard.general.string(forType: .string) ?? ""
        pastePresented = true
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(kind == "android" ? "Android" : "Windows Arm").font(.headline)
                Spacer(minLength: 0)
                if active && kind == "android" {
                    Text("Stream \(Int(model.streamFPS.rounded())) · Decoder \(Int(model.decoderFPS.rounded())) FPS")
                        .font(.caption.monospacedDigit())
                        .help("Empfangene Bilder / Decoder-Zuführung. Keine Messung der Spiel-FPS.")
                }
                Button { model.togglePlayerFullScreen(kind: kind) } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }.help("Player als Vollbild anzeigen")
            }.padding(12)
            ZStack {
                Color.black
                // Only the active guest owns the video layer and receives input.
                if active {
                    PlayerSurface(image: kind == "windows" ? model.playerImage : nil,
                                  videoLayer: kind == "android" ? model.h264Player.layer : nil,
                                  sourceSize: model.playerSize,
                                  pointer: { model.pointer(x: $0, y: $1, mask: $2) },
                                  key: { model.keyboard(code: $0, text: $1, down: $2) },
                                  paste: { beginPaste() },
                                  scroll: { model.scroll(x: $0, y: $1, horizontal: $2, vertical: $3, mask: $4) },
                                  resetScroll: { model.resetScroll() }, zoomPercent: fitsWindow ? nil : safeZoom)
                }
                if !active || model.playerSize == .zero {
                    VStack(spacing: 12) {
                        Image(systemName: kind == "android" ? "apps.iphone" : "desktopcomputer")
                            .font(.system(size: 42))
                        Text(active ? (kind == "windows" ? model.playerStatus : "System startet …") : "Gastsystem ist ausgeschaltet")
                            .multilineTextAlignment(.center)
                        if active && kind == "windows" {
                            Text(model.windowsBootMediaStatus).font(.caption).multilineTextAlignment(.center)
                                .textSelection(.enabled)
                        }
                    }.padding(24).frame(maxWidth: 650).foregroundStyle(.white.opacity(0.85)).allowsHitTesting(false)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                if kind == "android" {
                    Button("Text einfügen …", action: beginPaste).disabled(!active || model.playerSize == .zero)
                        .help("Text vom Mac nach Android übertragen. Auch mit ⌘V im Gastbild.")
                    if !model.androidPasteStatus.isEmpty { Text(model.androidPasteStatus).font(.caption) }
                }
                HStack {
                    Toggle("An Fenster anpassen", isOn: $fitsWindow).toggleStyle(.checkbox)
                    Spacer(minLength: 4)
                    if kind == "android" {
                        Button("Android-Auflösung …") { androidDisplayPresented = true }
                    } else {
                        Button("Windows-Einstellungen …", action: model.openWindowsDisplaySettings)
                            .disabled(!active || model.playerSize == .zero || model.windowsPasteBusy)
                            .help("Windows + I; danach System → Anzeige für die vom Gast unterstützten Auflösungen und Skalierungen.")
                    }
                }
                if !fitsWindow {
                    HStack {
                        Text("Ansicht")
                        Slider(value: $zoomPercent, in: 25...300, step: 5)
                        Text("\(Int(safeZoom)) %").monospacedDigit().frame(width: 50, alignment: .trailing)
                        Button("100 %") { zoomPercent = 100 }
                    }
                }
                Text(fitsWindow
                    ? "Zwei Finger: im Gast scrollen. Bild passt sich der Fenstergröße an."
                    : "100 % = ein Gast-Bildpixel pro Mac-Bildpixel. Bild über Scrollleisten verschieben; zwei Finger scrollen im Gast.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if kind == "windows" {
                    Text("Auflösung und Textgröße in Windows: System → Anzeige. Die verfügbaren Modi hängen vom Gasttreiber ab; „Ansicht“ vergrößert nur das Playerbild.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if kind == "windows" {
                    HStack {
                        Button("Einrichtungskonsole öffnen", action: model.openWindowsSetupConsole)
                            .disabled(!active || model.playerSize == .zero || model.windowsPasteBusy)
                            .help("Sendet Shift + F10 direkt an Windows, ohne eine Funktionstaste auf dem Mac zu drücken.")
                        Spacer(minLength: 0)
                    }
                    Text("Sendet Shift + F10. In Windows Setup öffnet das normalerweise eine Konsole.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Text einfügen …", action: beginPaste)
                            .disabled(!active || model.playerSize == .zero || model.windowsPasteBusy)
                            .help("Text aus der Mac-Zwischenablage in Windows eingeben. Auch mit ⌘V im Windows-Bild.")
                        if model.windowsPasteBusy {
                            ProgressView().controlSize(.small)
                            Button("Abbrechen", action: model.cancelWindowsPaste)
                        }
                        Spacer(minLength: 0)
                    }
                    if !model.windowsPasteStatus.isEmpty {
                        Text(model.windowsPasteStatus).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 12) {
                    if kind == "android" {
                        Button { model.androidNavigation(4) } label: { Image(systemName: "chevron.left") }
                            .help("Zurück").disabled(!active)
                        Button { model.androidNavigation(3) } label: { Image(systemName: "house") }
                            .help("Startbildschirm").disabled(!active)
                        Button { model.androidNavigation(187) } label: { Image(systemName: "square.on.square") }
                            .help("Letzte Apps").disabled(!active)
                    }
                    Spacer(minLength: 0)
                    Button("Herunterfahren", action: model.shutdownGuest).disabled(!active)
                }
                Text(active ? model.playerStatus : "Apps, Dateien und Einstellungen bleiben gespeichert.")
                    .font(.caption).lineLimit(2)
                Text("Fenster schließen: Das Gastsystem läuft weiter.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
        .frame(minWidth: 360, minHeight: 480)
        .onAppear { zoomPercent = safeZoom }
        .sheet(isPresented: $pastePresented, onDismiss: { pasteDraft = "" }) {
            if kind == "android" { AndroidPasteSheet(model: model, text: $pasteDraft) }
            else { WindowsPasteSheet(model: model, text: $pasteDraft) }
        }
        .sheet(isPresented: $androidDisplayPresented) { AndroidDisplaySheet(model: model) }
    }
}
