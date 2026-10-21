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
            let view = ContentView(model: AppModel(applyPerformanceDefaults: false))
            try render(view, size: size, appearance: classic ? .aqua : .darkAqua,
                       to: directory.appendingPathComponent(name + ".png"))
        }
        defaults.set("automatic", forKey: WorkspaceAppearance.preferenceKey)
        try render(WorkspaceUtilityBar(tab: .dashboard, busy: true, canRefresh: false,
                                       diagnose: {}, refresh: {}),
                   size: NSSize(width: 180, height: 72), appearance: .darkAqua,
                   to: directory.appendingPathComponent("utilities-busy.png"))
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
