import Foundation

/// One policy is packaged alongside the player scripts and consumed by Swift
/// and Python. A resource or revision change cannot leave one consumer behind.
public struct GraphicsRuntimePolicy: Decodable, Sendable {
    public let version: Int
    public let embeddedPlayer: Int
    public let embeddedRevision: Int
    public let runtimeDependencies: Int
    public let resources: [String]

    public static func decode(_ data: Data) throws -> Self {
        let policy = try JSONDecoder().decode(Self.self, from: data)
        guard policy.version == 1, policy.embeddedPlayer > 0, policy.embeddedRevision > 0,
              policy.runtimeDependencies > 0, !policy.resources.isEmpty,
              Set(policy.resources).count == policy.resources.count,
              policy.resources.contains("runtime-policy.json"),
              policy.resources.allSatisfy({ name in
                  name.range(of: #"^[A-Za-z0-9][A-Za-z0-9_.-]*$"#, options: .regularExpression) != nil
              }) else { throw PolicyError.invalid }
        return policy
    }

    public static func load(from directory: URL) throws -> Self {
        try decode(Data(contentsOf: directory.appendingPathComponent("runtime-policy.json")))
    }

    public func accepts(receipt: Data) -> Bool {
        guard let value = try? JSONDecoder().decode(Receipt.self, from: receipt) else { return false }
        return value.embeddedPlayer == embeddedPlayer && value.embeddedRevision == embeddedRevision
            && value.runtimeDependencies == runtimeDependencies
    }

    /// Read and validate the complete source set before replacing any working
    /// file on the user's data drive. Missing fragments cannot cause a partial
    /// resource upgrade that later fails in the local player build.
    public func readResources(from directory: URL) throws -> [(name: String, data: Data)] {
        try resources.map { name in
            let url = directory.appendingPathComponent(name)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw PolicyError.invalid }
            return (name, try Data(contentsOf: url))
        }
    }

    private struct Receipt: Decodable {
        let embeddedPlayer: Int
        let embeddedRevision: Int
        let runtimeDependencies: Int
    }
    private enum PolicyError: LocalizedError {
        case invalid
        var errorDescription: String? { L10n.text("Grafiklaufzeit-Ressourcen sind unvollständig oder ungültig.") }
    }
}
