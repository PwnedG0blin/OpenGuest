import Foundation

/// Only successful runs of the private main-branch workflow may supply updates.
public struct PrivateUpdateRun: Decodable, Sendable {
    public let id: Int64
    public let status: String
    public let conclusion: String?
    public let headBranch: String
    public let headSHA: String
    public let event: String
    enum CodingKeys: String, CodingKey {
        case id, status, conclusion, event
        case headBranch = "head_branch", headSHA = "head_sha"
    }
    public var eligible: Bool {
        headSHA.count == 40 && headSHA.allSatisfy({ "0123456789abcdef".contains($0) }) &&
        id > 0 && status == "completed" && conclusion == "success" && headBranch == "main" &&
        (event == "workflow_dispatch" || event == "push")
    }
}

public struct PrivateUpdateArtifact: Decodable, Sendable {
    public static let prefix = "Stratovo-Private-Beta-App-Build"
    public let id: Int64
    public let name: String
    public let size: Int64
    public let expired: Bool
    public let digest: String?
    public let workflowRun: Run
    public struct Run: Decodable, Sendable {
        public let id: Int64
        public let repositoryID: Int64
        public let headRepositoryID: Int64
        public let headBranch: String
        public let headSHA: String
        enum CodingKeys: String, CodingKey {
            case id
            case repositoryID = "repository_id", headRepositoryID = "head_repository_id"
            case headBranch = "head_branch", headSHA = "head_sha"
        }
    }
    enum CodingKeys: String, CodingKey {
        case id, name, expired, digest
        case size = "size_in_bytes", workflowRun = "workflow_run"
    }
    public var build: Int? {
        guard name.hasPrefix(Self.prefix) else { return nil }
        let value = String(name.dropFirst(Self.prefix.count))
        guard !value.isEmpty, value.first != "0", value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(value)
    }
    public var sha256: String? {
        guard let digest, digest.hasPrefix("sha256:") else { return nil }
        let value = String(digest.dropFirst(7))
        guard value.count == 64, value.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        return value
    }
    public func isTrusted(run: PrivateUpdateRun) -> Bool {
        run.eligible && id > 0 && !expired && size > 0 && size <= 100 * 1024 * 1024 && build != nil && sha256 != nil &&
        workflowRun.id == run.id && workflowRun.repositoryID > 0 && workflowRun.repositoryID == workflowRun.headRepositoryID &&
        workflowRun.headBranch == "main" && workflowRun.headSHA == run.headSHA
    }
    public static func safeArchiveEntries(_ entries: [String]) -> Bool {
        !entries.isEmpty && entries.allSatisfy { entry in
            let components = entry.split(separator: "/", omittingEmptySubsequences: false)
            return !entry.hasPrefix("/") && !entry.contains("\\") && !entry.contains("\0") &&
                !components.contains("..") && components.first == "Stratovo.app"
        }
    }
}
