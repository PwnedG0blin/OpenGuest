import AppKit
import AVFoundation
import SwiftUI

@MainActor
struct PlayerSurface: NSViewRepresentable {
    let image: NSImage?
    let videoLayer: AVSampleBufferDisplayLayer?
    let sourceSize: CGSize
    let pointer: (Int, Int, UInt8) -> Void
    let key: (UInt16, String, Bool) -> Void
    var paste: (() -> Void)? = nil

    func makeNSView(context: Context) -> GuestSurface { GuestSurface() }
    func updateNSView(_ view: GuestSurface, context: Context) {
        view.configure(image: image, video: videoLayer, size: sourceSize, pointer: pointer, key: key, paste: paste)
    }
    static func dismantleNSView(_ nsView: GuestSurface, coordinator: ()) { nsView.detach() }
}

@MainActor
final class GuestSurface: NSView {
    private var video: AVSampleBufferDisplayLayer?
    private var sourceSize = CGSize.zero
    private var pointer: ((Int, Int, UInt8) -> Void)?
    private var key: ((UInt16, String, Bool) -> Void)?
    private var pasteAction: (() -> Void)?
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
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func configure(image: NSImage?, video: AVSampleBufferDisplayLayer?, size: CGSize,
                   pointer: @escaping (Int, Int, UInt8) -> Void, key: @escaping (UInt16, String, Bool) -> Void,
                   paste: (() -> Void)? = nil) {
        sourceSize = size; self.pointer = pointer; self.key = key; pasteAction = paste
        if self.video !== video {
            self.video?.removeFromSuperlayer()
            self.video = video
            if let video { layer?.addSublayer(video) }
        }
        if let image { layer?.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil) }
        else { layer?.contents = nil }
        needsLayout = true
    }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        video?.frame = bounds
        CATransaction.commit()
    }
    func detach() { releaseKeys(); video?.removeFromSuperlayer(); video = nil }
    override func resignFirstResponder() -> Bool { releaseKeys(); return super.resignFirstResponder() }
    private func releaseKeys() {
        for (code, text) in held { key?(code, text, false) }
        held.removeAll()
        pendingCommand.removeAll()
    }
    private func point(_ event: NSEvent, mask: UInt8) {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return }
        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        guard scale.isFinite, scale > 0 else { return }
        let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        let p = convert(event.locationInWindow, from: nil)
        let x = Int((p.x - origin.x) / scale), y = Int((p.y - origin.y) / scale)
        pointer?(max(0, min(Int(sourceSize.width) - 1, x)), max(0, min(Int(sourceSize.height) - 1, y)), mask)
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); point(event, mask: 1) }
    override func mouseDragged(with event: NSEvent) { point(event, mask: 1) }
    override func mouseUp(with event: NSEvent) { point(event, mask: 0) }
    override func rightMouseDown(with event: NSEvent) { window?.makeFirstResponder(self); point(event, mask: 4) }
    override func rightMouseDragged(with event: NSEvent) { point(event, mask: 4) }
    override func rightMouseUp(with event: NSEvent) { point(event, mask: 0) }
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
