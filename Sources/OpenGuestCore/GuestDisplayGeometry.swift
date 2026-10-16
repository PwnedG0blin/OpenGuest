import Foundation
import CoreGraphics

public struct GuestDisplayGeometry {
    public let documentSize: CGSize
    public let imageRect: CGRect
    public let scale: CGFloat
    private let source: CGSize

    public init(source: CGSize, viewport: CGSize, zoomPercent: Double? = nil, backingScale: Double = 1) {
        self.source = source
        guard source.width > 0, source.height > 0, source.width <= 8192, source.height <= 8192,
              source.width.isFinite, source.height.isFinite,
              viewport.width > 0, viewport.height > 0, viewport.width.isFinite, viewport.height.isFinite else {
            scale = 0; documentSize = .zero; imageRect = .zero; return
        }
        if let zoomPercent, zoomPercent.isFinite {
            let backing = backingScale.isFinite ? max(1, backingScale) : 1
            scale = CGFloat(max(25, min(300, zoomPercent)) / 100 / backing)
        } else {
            scale = min(viewport.width / source.width, viewport.height / source.height)
        }
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        documentSize = CGSize(width: max(viewport.width, size.width), height: max(viewport.height, size.height))
        imageRect = CGRect(x: (documentSize.width - size.width) / 2, y: (documentSize.height - size.height) / 2,
                           width: size.width, height: size.height)
    }
    public func point(at point: CGPoint, clamped: Bool) -> (Int, Int)? {
        guard scale > 0, point.x.isFinite, point.y.isFinite,
              clamped || imageRect.contains(point) else { return nil }
        let x = max(0, min(source.width - 1, (point.x - imageRect.minX) / scale))
        let y = max(0, min(source.height - 1, (point.y - imageRect.minY) / scale))
        return (Int(x), Int(y))
    }
}
