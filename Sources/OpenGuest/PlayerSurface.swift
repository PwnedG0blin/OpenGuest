import AppKit
import AVFoundation
import SwiftUI
import OpenGuestCore

@MainActor
struct PlayerSurface: NSViewRepresentable {
    let image: NSImage?
    let videoLayer: AVSampleBufferDisplayLayer?
    let sourceSize: CGSize
    let pointer: (Int, Int, UInt8) -> Void
    let key: (UInt16, String, Bool) -> Void
    var paste: (() -> Void)? = nil
    var scroll: ((Int, Int, Double, Double, UInt8) -> Void)? = nil
    var resetScroll: (() -> Void)? = nil
    var zoomPercent: Double? = nil
    var allowsScrollMomentum = true
    var touchScroll: ((Int, Int, Double, Double, GuestTouchScrollPhase) -> Void)? = nil

    func makeNSView(context: Context) -> GuestViewport { GuestViewport() }
    func updateNSView(_ view: GuestViewport, context: Context) {
        view.configure(image: image, video: videoLayer, size: sourceSize, pointer: pointer, key: key,
                       paste: paste, scroll: scroll, resetScroll: resetScroll, zoomPercent: zoomPercent, allowsScrollMomentum: allowsScrollMomentum, touchScroll: touchScroll)
    }
    static func dismantleNSView(_ nsView: GuestViewport, coordinator: ()) { nsView.surface.detach() }
}

@MainActor
final class GuestViewport: NSScrollView {
    let surface = GuestSurface()
    private var sourceSize = CGSize.zero
    private var zoomPercent: Double?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        borderType = .noBorder; backgroundColor = .black; drawsBackground = true
        hasVerticalScroller = true; hasHorizontalScroller = true
        autohidesScrollers = true; scrollerStyle = .overlay
        documentView = surface
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func configure(image: NSImage?, video: AVSampleBufferDisplayLayer?, size: CGSize,
                   pointer: @escaping (Int, Int, UInt8) -> Void, key: @escaping (UInt16, String, Bool) -> Void,
                   paste: (() -> Void)?, scroll: ((Int, Int, Double, Double, UInt8) -> Void)?,
                   resetScroll: (() -> Void)?, zoomPercent: Double?, allowsScrollMomentum: Bool = true,
                   touchScroll: ((Int, Int, Double, Double, GuestTouchScrollPhase) -> Void)? = nil) {
        sourceSize = size; self.zoomPercent = zoomPercent
        surface.configure(image: image, video: video, size: size, pointer: pointer, key: key,
                          paste: paste, scroll: scroll, resetScroll: resetScroll, allowsScrollMomentum: allowsScrollMomentum, touchScroll: touchScroll)
        updateGeometry()
    }
    override func layout() { super.layout(); updateGeometry() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); updateGeometry() }
    private func updateGeometry() {
        let geometry = GuestDisplayGeometry(source: sourceSize, viewport: contentSize,
            zoomPercent: zoomPercent, backingScale: Double(window?.backingScaleFactor ?? 1))
        let oldCenter = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        let oldSource = surface.sourcePoint(at: oldCenter, clamped: true)
        let changed = surface.frame.size != geometry.documentSize || surface.imageRect != geometry.imageRect
        surface.setFrameSize(geometry.documentSize)
        surface.setGeometry(geometry)
        // Keep the AV video layer in sync immediately after live resolution or window changes.
        surface.layoutSubtreeIfNeeded()
        if changed {
            let center = oldSource.map { CGPoint(x: geometry.imageRect.minX + CGFloat($0.0) * geometry.scale,
                                                 y: geometry.imageRect.minY + CGFloat($0.1) * geometry.scale) }
                ?? CGPoint(x: geometry.documentSize.width / 2, y: geometry.documentSize.height / 2)
            contentView.scroll(to: CGPoint(x: max(0, min(geometry.documentSize.width - contentSize.width, center.x - contentSize.width / 2)),
                                          y: max(0, min(geometry.documentSize.height - contentSize.height, center.y - contentSize.height / 2))))
            reflectScrolledClipView(contentView)
        }
    }
}

@MainActor
final class GuestSurface: NSView {
    private var video: AVSampleBufferDisplayLayer?
    private var sourceSize = CGSize.zero
    private var pointer: ((Int, Int, UInt8) -> Void)?
    private var key: ((UInt16, String, Bool) -> Void)?
    private var pasteAction: (() -> Void)?
    private var scrollAction: ((Int, Int, Double, Double, UInt8) -> Void)?
    private var resetScrollAction: (() -> Void)?
    private var scrollAnchor: (Int, Int)?
    private var scrollGesture = false
    private var allowsScrollMomentum = true
    private var touchScrollAction: ((Int, Int, Double, Double, GuestTouchScrollPhase) -> Void)?
    private var touchScrollActive = false
    private var pressedButtons: UInt8 = 0
    private var lastPointer: (Int, Int)?
    private let imageLayer = CALayer()
    private var geometry: GuestDisplayGeometry?
    var imageRect: CGRect { displayGeometry.imageRect }
    private var displayGeometry: GuestDisplayGeometry {
        geometry ?? GuestDisplayGeometry(source: sourceSize, viewport: bounds.size)
    }
    private var held: [UInt16: String] = [:]
    private var pendingCommand = Set<UInt16>()
    private var consumedKeys = Set<UInt16>()
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)
        imageLayer.contentsGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func configure(image: NSImage?, video: AVSampleBufferDisplayLayer?, size: CGSize,
                   pointer: @escaping (Int, Int, UInt8) -> Void, key: @escaping (UInt16, String, Bool) -> Void,
                   paste: (() -> Void)? = nil,
                   scroll: ((Int, Int, Double, Double, UInt8) -> Void)? = nil, resetScroll: (() -> Void)? = nil, allowsScrollMomentum: Bool = true,
                   touchScroll: ((Int, Int, Double, Double, GuestTouchScrollPhase) -> Void)? = nil) {
        if sourceSize != size || self.allowsScrollMomentum != allowsScrollMomentum || (touchScrollAction == nil) != (touchScroll == nil) { resetScrolling() }
        self.allowsScrollMomentum = allowsScrollMomentum
        self.touchScrollAction = touchScroll
        sourceSize = size; self.pointer = pointer; self.key = key; pasteAction = paste
        scrollAction = scroll; resetScrollAction = resetScroll
        if self.video !== video {
            self.video?.removeFromSuperlayer()
            self.video = video
            if let video { layer?.addSublayer(video) }
        }
        if let image { imageLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil) }
        else { imageLayer.contents = nil }
        needsLayout = true
    }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = imageRect
        imageLayer.contentsScale = window?.backingScaleFactor ?? 1
        video?.frame = imageRect
        CATransaction.commit()
    }
    func setGeometry(_ geometry: GuestDisplayGeometry) {
        if self.geometry?.imageRect != geometry.imageRect { resetScrolling() }
        self.geometry = geometry; needsLayout = true
    }
    func detach() { releaseKeys(); releasePointer(); resetScrolling(); video?.removeFromSuperlayer(); video = nil }
    override func resignFirstResponder() -> Bool {
        releaseKeys(); releasePointer(); resetScrolling(); return super.resignFirstResponder()
    }
    private func releasePointer() {
        if pressedButtons != 0, let p = lastPointer { pointer?(p.0, p.1, 0) }
        pressedButtons = 0; lastPointer = nil
    }
    private func resetScrolling() {
        if touchScrollActive { touchScrollAction?(0, 0, 0, 0, .cancelled) }
        touchScrollActive = false; scrollAnchor = nil; scrollGesture = false; resetScrollAction?()
    }
    private func releaseKeys() {
        for (code, text) in held { key?(code, text, false) }
        held.removeAll()
        pendingCommand.removeAll()
    }
    private func point(_ event: NSEvent, mask: UInt8) {
        guard let p = sourcePoint(at: convert(event.locationInWindow, from: nil), clamped: true) else { return }
        lastPointer = p
        pointer?(p.0, p.1, mask)
    }
    func sourcePoint(at point: CGPoint, clamped: Bool) -> (Int, Int)? { displayGeometry.point(at: point, clamped: clamped) }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); pressedButtons |= 1; point(event, mask: pressedButtons) }
    override func mouseDragged(with event: NSEvent) { point(event, mask: pressedButtons) }
    override func mouseUp(with event: NSEvent) { pressedButtons &= ~1; point(event, mask: pressedButtons) }
    override func rightMouseDown(with event: NSEvent) { window?.makeFirstResponder(self); pressedButtons |= 4; point(event, mask: pressedButtons) }
    override func rightMouseDragged(with event: NSEvent) { point(event, mask: pressedButtons) }
    override func rightMouseUp(with event: NSEvent) { pressedButtons &= ~4; point(event, mask: pressedButtons) }
    override func scrollWheel(with event: NSEvent) {
        guard scrollAction != nil else { super.scrollWheel(with: event); return }
        scrollInput(at: convert(event.locationInWindow, from: nil),
                    delta: GuestScrollDelta(deltaX: Double(event.scrollingDeltaX), deltaY: Double(event.scrollingDeltaY),
                                             precise: event.hasPreciseScrollingDeltas),
                    phase: event.phase, momentum: event.momentumPhase)
    }
    func scrollInput(at location: CGPoint, delta: GuestScrollDelta, phase: NSEvent.Phase, momentum: NSEvent.Phase) {
        guard let scrollAction else { return }
        if !allowsScrollMomentum && !momentum.isEmpty { resetScrolling(); return }
        if phase.contains(.cancelled) || momentum.contains(.cancelled) { resetScrolling(); return }
        let gestured = !phase.isEmpty || !momentum.isEmpty
        if phase.contains(.began) || (gestured && !scrollGesture) {
            resetScrolling(); scrollGesture = true
            scrollAnchor = sourcePoint(at: location, clamped: false)
        } else if !gestured && scrollGesture { resetScrolling() }
        let point = gestured ? scrollAnchor : sourcePoint(at: location, clamped: false)
        if let point {
            if delta.horizontal != 0 || delta.vertical != 0 {
                if let touchScrollAction {
                    if pressedButtons == 0 {
                        if !touchScrollActive { touchScrollAction(point.0, point.1, 0, 0, .began); touchScrollActive = true }
                        touchScrollAction(point.0, point.1, delta.horizontal, delta.vertical, .changed)
                    }
                } else { scrollAction(point.0, point.1, delta.horizontal, delta.vertical, pressedButtons) }
            }
        }
        if touchScrollActive && (phase.contains(.ended) || momentum.contains(.ended) || !gestured) {
            touchScrollAction?(0, 0, 0, 0, .ended); touchScrollActive = false
        }
        if momentum.contains(.ended) { resetScrolling() }
    }
    override func keyDown(with event: NSEvent) {
        if consumePaste(event) { return }
        consumedKeys.remove(event.keyCode)
        for code in pendingCommand.sorted() { held[code] = ""; key?(code, "", true) }
        pendingCommand.removeAll()
        let text = event.characters ?? ""
        held[event.keyCode] = text
        key?(event.keyCode, text, true)
    }
    override func keyUp(with event: NSEvent) {
        if consumedKeys.remove(event.keyCode) != nil { return }
        key?(event.keyCode, held.removeValue(forKey: event.keyCode) ?? event.characters ?? "", false)
    }
    override func flagsChanged(with event: NSEvent) {
        let flags: [UInt16: NSEvent.ModifierFlags] = [56: .shift, 60: .shift, 59: .control, 62: .control, 58: .option, 61: .option, 55: .command, 54: .command]
        guard let flag = flags[event.keyCode] else { return }
        let down = event.modifierFlags.contains(flag)
        // Delay Command until a non-paste key arrives. Otherwise Command+V would
        // briefly send a Windows key and open Start before text is entered.
        if flag == .command, pasteAction != nil {
            if down { pendingCommand.insert(event.keyCode) }
            else {
                let wasPending = pendingCommand.remove(event.keyCode) != nil
                if held.removeValue(forKey: event.keyCode) != nil { key?(event.keyCode, "", false) }
                else if wasPending { key?(event.keyCode, "", true); key?(event.keyCode, "", false) }
            }
            return
        }
        if down { held[event.keyCode] = "" } else { held.removeValue(forKey: event.keyCode) }
        key?(event.keyCode, "", down)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if consumePaste(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func consumePaste(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.keyCode == 9, let pasteAction,
              event.modifierFlags.contains(.command),
              event.modifierFlags.intersection([.control, .option, .shift]).isEmpty else { return false }
        consumedKeys.insert(event.keyCode)
        releaseKeys()
        pasteAction()
        return true
    }

    @objc func paste(_ sender: Any?) {
        guard let pasteAction else { return }
        releaseKeys()
        pasteAction()
    }
}
