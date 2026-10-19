import Foundation

public enum WindowsGraphics: String, CaseIterable, Hashable, Sendable {
    case basic, virtio
    public var title: String { self == .basic ? "Basisgrafik · bisherige Anzeige" : "Virtio-GPU · ARM64-Grafiktreiber nötig" }
    public func device(resolution: WindowsDisplayMode) -> String {
        self == .basic ? "ramfb" : "virtio-gpu-pci,id=display0,xres=\(resolution.width),yres=\(resolution.height)"
    }
}
public enum WindowsDisplayMode: String, CaseIterable, Hashable, Sendable {
    case hd, fullHD, qhd
    public var width: Int { self == .hd ? 1280 : (self == .fullHD ? 1920 : 2560) }
    public var height: Int { self == .hd ? 720 : (self == .fullHD ? 1080 : 1440) }
    public var title: String { "\(width) × \(height) · 16:9" }
}
