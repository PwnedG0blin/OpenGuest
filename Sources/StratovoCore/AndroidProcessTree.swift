import Foundation

public enum AndroidProcessTree {
    public static func descendants(of parent: Int32, snapshot: String) -> [Int32] {
        let pairs: [(Int32, Int32)] = snapshot.split(separator: "\n").compactMap { line in
            let values = line.split(whereSeparator: { $0.isWhitespace })
            guard values.count == 2, let pid = Int32(values[0]), let ppid = Int32(values[1]), pid > 1 else { return nil }
            return (pid, ppid)
        }
        var found: Set<Int32> = [parent]
        var children: [Int32] = []
        for _ in 0..<16 {
            let next = pairs.filter { found.contains($0.1) && !found.contains($0.0) }.map { $0.0 }
            guard !next.isEmpty else { break }
            found.formUnion(next); children += next
        }
        return children
    }
}
