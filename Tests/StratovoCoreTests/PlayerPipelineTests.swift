import Foundation
import XCTest
@testable import StratovoCore

final class PlayerPipelineTests: XCTestCase {
    func testFragmentedAndCoalescedWireDataRemainsOrdered() {
        let source = Data((0..<700_000).map { UInt8($0 % 251) })
        var buffer = StreamByteBuffer(), received = Data(), position = 0, reads = 0
        while position < source.count {
            let end = min(source.count, position + 7777)
            buffer.append(source.subdata(in: position..<end)); position = end
            while buffer.count >= (reads.isMultiple(of: 2) ? 12 : 4003) {
                received.append(buffer.read(reads.isMultiple(of: 2) ? 12 : 4003)!); reads += 1
            }
        }
        received.append(buffer.read(buffer.count)!)
        XCTAssertEqual(received, source); XCTAssertEqual(buffer.count, 0)
    }
    func testIncompleteReadDoesNotConsumeAndCompactionKeepsReturnedData() {
        var buffer = StreamByteBuffer()
        buffer.append(Data(repeating: 7, count: 400_000))
        XCTAssertNil(buffer.read(400_001)); XCTAssertEqual(buffer.count, 400_000)
        let first = buffer.read(300_000)!
        buffer.append(Data([1, 2, 3]))
        XCTAssertEqual(first, Data(repeating: 7, count: 300_000))
        XCTAssertEqual(buffer.read(100_003), Data(repeating: 7, count: 100_000) + Data([1, 2, 3]))
        XCTAssertEqual(buffer.read(0), Data()); XCTAssertNil(buffer.read(-1))
    }
    func testFrameCadenceCountsNetworkTimeAndDoesNotCatchUpWithBursts() {
        var cadence = FrameRequestCadence(fps: 60)
        XCTAssertEqual(cadence.delay(at: 100), 0)
        cadence.requested(at: 100)
        XCTAssertEqual(cadence.delay(at: 100.010), 1 / 60.0 - 0.010, accuracy: 0.000001)
        XCTAssertEqual(cadence.delay(at: 100.040), 0)
        cadence.requested(at: 100.040)
        XCTAssertEqual(cadence.delay(at: 100.040), 1 / 60.0, accuracy: 0.000001)
        XCTAssertEqual(cadence.delay(at: 99), 0); XCTAssertEqual(cadence.delay(at: .nan), 0)
    }
    func testRectangleWritesKeepSurroundingPixelsAndPublishedSnapshot() throws {
        var frame = RawFramebuffer(); try frame.resize(width: 4, height: 3)
        try frame.apply(x: 0, y: 0, width: 4, height: 3, data: Data(repeating: 7, count: 48))
        let published = frame.bytes
        try frame.apply(x: 1, y: 0, width: 2, height: 2, data: Data(repeating: 9, count: 16))
        for y in 0..<3 { for x in 0..<4 {
            XCTAssertEqual(frame.bytes[(y * 4 + x) * 4], y < 2 && (1...2).contains(x) ? 9 : 7)
        } }
        XCTAssertEqual(published, Data(repeating: 7, count: 48))
    }
    func testMalformedRectanglesNeverMutateFramebuffer() throws {
        var frame = RawFramebuffer(); try frame.resize(width: 4, height: 3)
        let before = frame.bytes
        for rect in [(-1, 0, 1, 1, 4), (4, 0, 1, 1, 4), (0, 2, 1, 2, 8), (0, 0, 2, 2, 15), (0, 0, 0, 1, 0)] {
            XCTAssertThrowsError(try frame.apply(x: rect.0, y: rect.1, width: rect.2, height: rect.3, data: Data(count: rect.4)))
            XCTAssertEqual(frame.bytes, before)
        }
        XCTAssertThrowsError(try frame.resize(width: 4097, height: 1)); XCTAssertEqual(frame.bytes, before)
        try frame.resize(width: 1, height: 3); XCTAssertEqual(frame.bytes, Data(count: 12))
    }
    func testLogReaderSkipsUnchangedFilesAndHandlesAppendAndTruncation() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 65, count: 180_000).write(to: url)
        let initial = try XCTUnwrap(SessionLogReader.read(url: url, previousSize: nil, includeHeader: true))
        XCTAssertEqual(initial.tail.utf8.count, 60_000); XCTAssertEqual(initial.header.utf8.count, 96_000)
        XCTAssertNil(try SessionLogReader.read(url: url, previousSize: initial.size, includeHeader: true))
        let file = try FileHandle(forWritingTo: url); try file.seekToEnd(); try file.write(contentsOf: Data("end".utf8)); try file.close()
        let next = try XCTUnwrap(SessionLogReader.read(url: url, previousSize: initial.size, includeHeader: false))
        XCTAssertTrue(next.tail.hasSuffix("end")); XCTAssertEqual(next.header, "")
        try Data("new".utf8).write(to: url)
        XCTAssertEqual(try SessionLogReader.read(url: url, previousSize: next.size, includeHeader: false)?.tail, "new")
    }
}
