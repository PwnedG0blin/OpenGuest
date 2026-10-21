import Foundation

/// The media stream's actual range varies between Android images.
public struct AndroidMediaVolume: Equatable, Sendable {
    public let index: Int
    public let minimum: Int
    public let maximum: Int
    public var percent: Double { Double(index - minimum) / Double(maximum - minimum) * 100 }
    public var muted: Bool { index == minimum }

    public init(output: String) throws {
        let pattern = #"volume is (\d+) in range \[(\d+)\.\.(\d+)\]"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let currentRange = Range(match.range(at: 1), in: output),
              let minRange = Range(match.range(at: 2), in: output),
              let maxRange = Range(match.range(at: 3), in: output),
              let current = Int(output[currentRange]), let min = Int(output[minRange]),
              let max = Int(output[maxRange]), max > min, (min...max).contains(current) else {
            throw NSError(domain: "Stratovo.Audio", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Android hat keine gültige Medienlautstärke gemeldet."])
        }
        self.index = current; self.minimum = min; self.maximum = max
    }

    public func index(forPercent value: Double) -> Int {
        guard value.isFinite else { return index }
        return minimum + Int((Swift.max(0, Swift.min(100, value)) / 100 * Double(maximum - minimum)).rounded())
    }
}
