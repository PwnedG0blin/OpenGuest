import Foundation

public enum WindowsDisk {
    public static func capacityGiB(_ text: String) throws -> Int {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), (64...4096).contains(value) else {
            throw StorageMigration.failure("Bitte eine ganze Festplattengröße zwischen 64 und 4096 GB eingeben.")
        }
        return value
    }
    public static func virtualBytes(from data: Data) throws -> Int64 {
        guard let info = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              info["format"] as? String == "qcow2", let size = info["virtual-size"] as? NSNumber,
              size.int64Value > 0, (info["backing-filename"] as? String ?? "").isEmpty else {
            throw StorageMigration.failure("Die Windows-Festplatte ist kein unterstütztes eigenständiges QCOW2-Abbild.")
        }
        return size.int64Value
    }
    public static func requiresGrowth(currentBytes: Int64, requestedGiB: Int) throws -> Bool {
        let value = try capacityGiB(String(requestedGiB))
        let target = Int64(value) * 1_073_741_824
        guard currentBytes <= target else {
            throw StorageMigration.failure("Die vorhandene Windows-Festplatte ist größer als die gewünschte Größe. Verkleinern wird zum Schutz deiner Daten nicht durchgeführt.")
        }
        return currentBytes < target
    }
}
