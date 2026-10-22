import AppKit
import SwiftUI
import XCTest
import StratovoCore
@testable import Stratovo

/// CI-only visual review of the production views; never opens a VM or downloads.
final class WorkspacePreviewTests: XCTestCase {
    @MainActor
    func testRenderProductionWorkspaceForReview() throws {
        guard let destination = ProcessInfo.processInfo.environment["STRATOVO_PREVIEW_DIRECTORY"] else {
            throw XCTSkip("Visual captures run only in the dedicated CI step.")
        }
        let directory = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let infoURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Packaging/Info.plist")
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: Data(contentsOf: infoURL), options: [], format: nil) as? [String: Any])
        let releaseLabel = AppPresentation.releaseLabel(info: info)
        for kind in ["windows", "android", "ubuntu"] {
            XCTAssertNotNil(WorkspaceArtwork.url(for: kind).flatMap { NSImage(contentsOf: $0) })
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        let oldAppearance = defaults.object(forKey: WorkspaceAppearance.preferenceKey)
        let oldLanguage = defaults.object(forKey: L10n.preferenceKey)
        defer {
            defaults.set(oldAppearance, forKey: WorkspaceAppearance.preferenceKey)
            defaults.set(oldLanguage, forKey: L10n.preferenceKey)
        }
        defaults.set("de", forKey: L10n.preferenceKey)
        for (name, size, classic) in [
            ("midnight-large", NSSize(width: 1240, height: 850), false),
            ("midnight-small", NSSize(width: 860, height: 650), false),
            ("classic-large", NSSize(width: 1240, height: 850), true)
        ] {
            defaults.set(classic ? "classic" : "automatic", forKey: WorkspaceAppearance.preferenceKey)
            let view = ContentView(model: AppModel(applyPerformanceDefaults: false), releaseLabel: releaseLabel)
            try render(view, size: size, appearance: classic ? .aqua : .darkAqua,
                       to: directory.appendingPathComponent(name + ".png"))
        }
        defaults.set("automatic", forKey: WorkspaceAppearance.preferenceKey)
        try render(WorkspaceUtilityBar(tab: .dashboard, busy: true, canRefresh: false,
                                       diagnose: {}, refresh: {}),
                   size: NSSize(width: 180, height: 72), appearance: .darkAqua,
                   to: directory.appendingPathComponent("utilities-busy.png"))
        for (name, size, kind, classic) in [
            ("android-player-small", NSSize(width: 360, height: 680), "android", false),
            ("android-player-large", NSSize(width: 620, height: 1000), "android", false),
            ("ubuntu-player", NSSize(width: 1100, height: 780), "ubuntu", false),
            ("android-player-classic", NSSize(width: 520, height: 850), "android", true)
        ] {
            defaults.set(classic ? "classic" : "automatic", forKey: WorkspaceAppearance.preferenceKey)
            try render(GuestPlayerView(model: AppModel(applyPerformanceDefaults: false), kind: kind),
                       size: size, appearance: classic ? .aqua : .darkAqua,
                       to: directory.appendingPathComponent(name + ".png"))
        }
        defaults.set("automatic", forKey: WorkspaceAppearance.preferenceKey)
        let outputModel = AppModel(applyPerformanceDefaults: false)
        let previousOutput = outputModel.androidOutputMode
        defer { outputModel.androidOutputMode = previousOutput }
        outputModel.androidOutputMode = .direct
        try render(AndroidOutputControls(model: outputModel).padding(20).modifier(WorkspaceDialogTheme()),
                   size: NSSize(width: 520, height: 320), appearance: .darkAqua,
                   to: directory.appendingPathComponent("android-direct-output.png"))
        let model = AppModel(applyPerformanceDefaults: false)
        try render(AndroidDisplaySheet(model: model), size: NSSize(width: 500, height: 600), appearance: .darkAqua,
                   to: directory.appendingPathComponent("android-resolution.png"))
        try render(AndroidPasteSheet(model: model, text: .constant("Grüße vom Mac 👋")),
                   size: NSSize(width: 560, height: 560), appearance: .darkAqua,
                   to: directory.appendingPathComponent("android-paste.png"))
        try render(WindowsPasteSheet(model: model, text: .constant("Text aus Stratovo")),
                   size: NSSize(width: 600, height: 690), appearance: .darkAqua,
                   to: directory.appendingPathComponent("windows-paste.png"))
        try render(WorkspaceHelpSheet(title: "Android") { WorkspaceGuide(tab: .android) },
                   size: NSSize(width: 640, height: 540), appearance: .darkAqua,
                   to: directory.appendingPathComponent("android-help.png"))
        try render(SessionDiagnosticsView(model: model), size: NSSize(width: 780, height: 520), appearance: .darkAqua,
                   to: directory.appendingPathComponent("diagnostics.png"))
    }

    @MainActor
    private func render<V: View>(_ root: V, size: NSSize, appearance: NSAppearance.Name, to file: URL) throws {
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: file)
        XCTAssertGreaterThan(png.count, 1000)
    }
}
