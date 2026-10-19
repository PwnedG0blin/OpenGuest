import AVFoundation
import Foundation
import StratovoCore

struct PreparedH264Packet: Sendable { let units: [Data]; let avcc: Data; let keyframe: Bool }
// CoreMedia objects are created once, then handed off immutably to the display actor.
struct ImmutableVideoFormat: @unchecked Sendable { let value: CMVideoFormatDescription }
struct ImmutableVideoSample: @unchecked Sendable { let value: CMSampleBuffer }
actor H264PacketBuilder {
    func prepare(_ data: Data) throws -> PreparedH264Packet {
        let units = ScrcpyWire.nalUnits(data)
        guard !units.isEmpty else { throw failure(L10n.text("Ungültiger H.264-Datenstrom.")) }
        var avcc = Data(); avcc.reserveCapacity(data.count)
        for unit in units where ![7, 8, 9].contains(unit[0] & 31) {
            avcc.append(ScrcpyWire.integer(UInt64(unit.count), bytes: 4)); avcc.append(unit)
        }
        return PreparedH264Packet(units: units, avcc: avcc, keyframe: units.contains { $0[0] & 31 == 5 })
    }
    func sample(avcc: Data, pts: UInt64, format: ImmutableVideoFormat) throws -> ImmutableVideoSample {
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: avcc.count, blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: avcc.count, flags: 0, blockBufferOut: &block) == noErr, let block else {
            throw failure(L10n.text("Video-Puffer konnte nicht erstellt werden."))
        }
        let copyStatus = avcc.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: avcc.count)
        }
        guard copyStatus == noErr else { throw failure(L10n.text("Video-Puffer konnte nicht gefüllt werden.")) }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMTime(value: Int64(pts), timescale: 1_000_000), decodeTimeStamp: .invalid)
        var size = avcc.count
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format.value,
            sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample) == noErr, let sample else {
            throw failure(L10n.text("Videoframe konnte nicht erstellt werden."))
        }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return ImmutableVideoSample(value: sample)
    }
    private func failure(_ text: String) -> NSError {
        NSError(domain: "OpenGuest.Video", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
