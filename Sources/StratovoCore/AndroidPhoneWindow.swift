import Foundation
import CoreGraphics

public enum AndroidPhoneWindow {
    public static func size(source: CGSize, available: CGSize, chrome: CGSize) -> CGSize {
        let ratio = source.width > 0 && source.height > 0 && source.width.isFinite && source.height.isFinite
            ? source.width / source.height : 1440.0 / 3120.0
        let widthLimit = max(1, available.width), heightLimit = max(1, available.height)
        let contentHeight = max(1, heightLimit - max(0, chrome.height))
        let width = min(widthLimit, max(min(360, widthLimit), contentHeight * ratio + max(0, chrome.width)))
        return CGSize(width: width, height: heightLimit)
    }
}
