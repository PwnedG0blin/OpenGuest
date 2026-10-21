import Foundation
import XCTest
@testable import Stratovo

final class GuestAudioTests: XCTestCase {
    @MainActor
    func testAndroidMediaCommandsReadRealRangeMuteRestoreAndDisconnect() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("stratovo-audio-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let adb = root.appendingPathComponent("adb")
        let script = #"""
        #!/bin/sh
        base="$(dirname "$0")"
        printf '%s\n' "$@" >> "$base/commands"
        value="$(cat "$base/volume" 2>/dev/null || printf 7)"
        previous=''
        for argument in "$@"; do
            if [ "$previous" = '--set' ]; then value="$argument"; fi
            previous="$argument"
        done
        printf '%s' "$value" > "$base/volume"
        printf '[v] volume is %s in range [0..15]\n' "$value"
        """#
        try script.write(to: adb, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: adb.path)
        let audio = GuestAudioController()
        audio.connect(.android(adb: adb.path, serial: "emulator-5556"), kind: "android")
        try await settled(audio)
        XCTAssertEqual(audio.volume?.index, 7)
        audio.setPercent(20); audio.setPercent(80)
        try await settled(audio)
        XCTAssertEqual(audio.volume?.index, 12, "The latest slider target must win")
        audio.toggleMute()
        try await settled(audio)
        XCTAssertEqual(audio.volume?.index, 0)
        audio.toggleMute()
        try await settled(audio)
        XCTAssertEqual(audio.volume?.index, 12, "Unmute restores the last audible guest level")
        let commands = try String(contentsOf: root.appendingPathComponent("commands"))
        XCTAssertTrue(commands.contains("emulator-5556\nshell\ncmd\nmedia_session\nvolume\n--stream\n3"))
        audio.setPercent(30)
        audio.disconnect()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(audio.volume)
        XCTAssertFalse(audio.connected)
        XCTAssertFalse(audio.busy)
    }
    @MainActor
    private func settled(_ audio: GuestAudioController) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while audio.busy && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(audio.busy, audio.status)
    }
}
