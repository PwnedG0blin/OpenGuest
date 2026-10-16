import AVFoundation
import Foundation
import OpenGuestCore

@MainActor
final class H264Player {
    let layer = AVSampleBufferDisplayLayer()
    var onSize: ((CGSize) -> Void)?
    private var format: CMVideoFormatDescription?
    private var sps = Data()
    private var pps = Data()
    private var waitingForKeyframe = true
    private var generation = 0
    private var submitted = 0
    private var epoch = ProcessInfo.processInfo.systemUptime
    private var recoveries = 0
    var onStatistics: ((Double, Int) -> Void)?

    init() { layer.videoGravity = .resizeAspect; layer.backgroundColor = CGColor(gray: 0, alpha: 1) }
    func reset() {
        generation += 1
        layer.flushAndRemoveImage(); format = nil; sps = Data(); pps = Data(); waitingForKeyframe = true
        submitted = 0; recoveries = 0; epoch = ProcessInfo.processInfo.systemUptime
        onStatistics?(0, 0)
    }

    func packet(_ data: Data, pts: UInt64, configuration: Bool) async throws {
        let packetGeneration = generation
        let units = ScrcpyWire.nalUnits(data)
        guard !units.isEmpty else { throw failure("Ungültiger H.264-Datenstrom.") }
        var changed = false
        for unit in units {
            if unit[0] & 31 == 7 && sps != unit { sps = unit; changed = true }
            if unit[0] & 31 == 8 && pps != unit { pps = unit; changed = true }
        }
        if changed, !sps.isEmpty, !pps.isEmpty { try configure() }
        guard !configuration, let format else { return }
        if units.contains(where: { $0[0] & 31 == 5 }) { waitingForKeyframe = false }
        guard !waitingForKeyframe else { return }
        var avcc = Data()
        for unit in units where ![7, 8, 9].contains(unit[0] & 31) {
            avcc += ScrcpyWire.integer(UInt64(unit.count), bytes: 4)
            avcc += unit
        }
        guard !avcc.isEmpty else { return }
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: avcc.count, blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: avcc.count, flags: 0, blockBufferOut: &block) == noErr, let block else {
            throw failure("Video-Puffer konnte nicht erstellt werden.")
        }
        let copyStatus = avcc.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: avcc.count)
        }
        guard copyStatus == noErr else { throw failure("Video-Puffer konnte nicht gefüllt werden.") }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMTime(value: Int64(pts), timescale: 1_000_000), decodeTimeStamp: .invalid)
        var size = avcc.count
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
            sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample) == noErr, let sample else {
            throw failure("Videoframe konnte nicht erstellt werden.")
        }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        if layer.status == .failed { throw failure("Mac-Videodecoder: \(layer.error?.localizedDescription ?? "Unbekannter Fehler")") }
        // Brief decoder backpressure must not immediately discard a reference chain.
        // Backpressure propagates to the stream reader; cap it to avoid unbounded latency.
        let deadline = ProcessInfo.processInfo.systemUptime + 0.060
        while !layer.isReadyForMoreMediaData {
            try Task.checkCancellation()
            guard packetGeneration == generation else { return }
            if ProcessInfo.processInfo.systemUptime >= deadline {
                layer.flush(); waitingForKeyframe = true; recoveries += 1
                onStatistics?(0, recoveries)
                return
            }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        try Task.checkCancellation()
        guard packetGeneration == generation else { return }
        layer.enqueue(sample)
        submitted += 1
        let now = ProcessInfo.processInfo.systemUptime
        if now - epoch >= 1 {
            onStatistics?(Double(submitted) / (now - epoch), recoveries)
            submitted = 0; epoch = now
        }
    }

    private func configure() throws {
        let sps = [UInt8](sps), pps = [UInt8](pps)
        var description: CMVideoFormatDescription?
        let status = sps.withUnsafeBufferPointer { s in
            pps.withUnsafeBufferPointer { p in
                let pointers = [s.baseAddress!, p.baseAddress!]
                let sizes = [s.count, p.count]
                return pointers.withUnsafeBufferPointer { pointers in
                    sizes.withUnsafeBufferPointer { sizes in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                            parameterSetCount: 2, parameterSetPointers: pointers.baseAddress!, parameterSetSizes: sizes.baseAddress!,
                            nalUnitHeaderLength: 4, formatDescriptionOut: &description)
                    }
                }
            }
        }
        guard status == noErr, let description else { throw failure("H.264-Konfiguration nicht unterstützt.") }
        layer.flushAndRemoveImage()
        waitingForKeyframe = true
        format = description
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        onSize?(CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height)))
    }
    private func failure(_ text: String) -> NSError {
        NSError(domain: "OpenGuest.Video", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
