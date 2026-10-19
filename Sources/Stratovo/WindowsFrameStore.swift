import AppKit
import Combine
import Foundation
import StratovoCore

/// Only the AppKit player subscribes to individual frames, not the whole SwiftUI app.
@MainActor
final class WindowsFrameStore: ObservableObject {
    @Published private(set) var image: NSImage?
    func publish(_ image: NSImage?) { self.image = image }
}
struct RenderedWindowsFrame: @unchecked Sendable { let image: CGImage }

actor WindowsFrameRenderer {
    private var framebuffer = RawFramebuffer()
    private var dirty = false
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    func resize(width: Int, height: Int) throws { try framebuffer.resize(width: width, height: height); dirty = true }
    func apply(x: Int, y: Int, width: Int, height: Int, data: Data) throws {
        try framebuffer.apply(x: x, y: y, width: width, height: height, data: data); dirty = true
    }
    func takeFrame() -> RenderedWindowsFrame? {
        guard dirty, framebuffer.width > 0, let provider = CGDataProvider(data: framebuffer.bytes as CFData),
              let image = CGImage(width: framebuffer.width, height: framebuffer.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: framebuffer.width * 4, space: colorSpace,
                                  bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        dirty = false
        return RenderedWindowsFrame(image: image)
    }
}
