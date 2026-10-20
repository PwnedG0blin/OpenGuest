import Foundation

// macOS selects the appropriate Trash on the source volume. Never delete or
// fall back to a cross-volume permanent removal when trashing is unavailable.
var results = [[String: String]]()
for path in CommandLine.arguments.dropFirst() {
    var destination: NSURL?
    do {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &destination)
        results.append(["source": path, "trash": destination?.path ?? "", "status": "moved"])
    } catch {
        results.append(["source": path, "status": "error", "error": error.localizedDescription])
    }
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
