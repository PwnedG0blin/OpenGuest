import Darwin
import Foundation
import StratovoCore

@MainActor
final class UbuntuSession {
    private var lockFD: Int32 = -1
    private var sockets: URL?
    func prepare(storage: GuestStorage, qemu: String, qemuImg: String, firmware: String,
                 variablesTemplate: String, installing: Bool, memory: Int, cores: Int) async throws -> (CommandSpec, String, String) {
        try storage.validate()
        let config = try UbuntuController.configuration(storage: storage)
        let root = config.deletingLastPathComponent()
        lockFD = Darwin.open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw GuestError.invalidResources }
        let sockets = URL(fileURLWithPath: "/tmp/og-\(UUID().uuidString.prefix(12))", isDirectory: true)
        try FileManager.default.createDirectory(at: sockets, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        self.sockets = sockets
        let updated = try UbuntuController.configuration(storage: storage, extra: ["qemu": qemu, "qemuImg": qemuImg,
            "firmware": firmware, "variablesTemplate": variablesTemplate, "memoryMiB": memory, "cores": cores,
            "socketDirectory": sockets.path])
        guard let helper = Bundle.main.resourceURL?.appendingPathComponent("GraphicsLab/ubuntu_vm.py") else { throw GuestError.invalidResources }
        let result = try await Task.detached {
            try CommandCapture.run(CommandSpec(executable: "/usr/bin/python3", arguments: [helper.path,
                "--config", updated.path, installing ? "plan-install" : "plan-start"]), timeout: 120)
        }.value
        guard result.status == 0, let line = result.output.split(separator: "\n").last,
              let data = String(line).data(using: .utf8),
              let args = try JSONSerialization.jsonObject(with: data) as? [String] else {
            throw GuestError.commandFailed(result.status, result.output)
        }
        return (CommandSpec(executable: qemu, arguments: args), sockets.appendingPathComponent("display.sock").path,
                sockets.appendingPathComponent("qmp.sock").path)
    }
    func stop() {
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
        if let sockets { try? FileManager.default.removeItem(at: sockets) }
        sockets = nil
    }
}
