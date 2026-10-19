import Foundation

public enum RuntimeDiscovery {
    /// Match QEMU's exact quoted device name, never a similarly named variant.
    public static func hasDevice(_ name: String, in help: String) -> Bool {
        help.components(separatedBy: .newlines).contains { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            return text.hasPrefix("name \"\(name)\"")
        }
    }

    public static func sdk(preferred: String = "", environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
        let candidates = [preferred, environment["ANDROID_HOME"] ?? "", environment["ANDROID_SDK_ROOT"] ?? "",
                          home.appendingPathComponent("Library/Android/sdk").path]
        return candidates.first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: "\($0)/emulator/emulator") }
    }

    public static func qemu(preferred: String = "") -> String? {
        [preferred, "/opt/homebrew/bin/qemu-system-aarch64", "/usr/local/bin/qemu-system-aarch64"]
            .first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func sibling(executable: String, name: String) -> String? {
        let path = URL(fileURLWithPath: executable).deletingLastPathComponent().appendingPathComponent(name).path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    public static func swtpm(preferred: String = "") -> String? {
        [preferred, "/opt/homebrew/bin/swtpm", "/usr/local/bin/swtpm"]
            .first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func variablesTemplate(firmware: String) -> String? {
        let root = URL(fileURLWithPath: firmware).deletingLastPathComponent()
        return ["edk2-arm-vars.fd", "edk2-aarch64-vars.fd"].map { root.appendingPathComponent($0).path }
            .first { FileManager.default.isReadableFile(atPath: $0) }
    }

    public static func firmware(qemu: String, preferred: String = "") -> String? {
        let prefix = URL(fileURLWithPath: qemu).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent()
        return [preferred, prefix.appendingPathComponent("share/qemu/edk2-aarch64-code.fd").path,
                "/opt/homebrew/share/qemu/edk2-aarch64-code.fd",
                "/usr/local/share/qemu/edk2-aarch64-code.fd"]
            .first { !$0.isEmpty && FileManager.default.isReadableFile(atPath: $0) }
    }

    public static func parseINI(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), !line.hasPrefix(";"), let split = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<split]).trimmingCharacters(in: .whitespaces)
            values[key] = String(line[line.index(after: split)...]).trimmingCharacters(in: .whitespaces)
        }
        return values
    }

    public static func avdConfig(name: String, environment: [String: String] = ProcessInfo.processInfo.environment,
                                 home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String: String] {
        // Do not let malformed engine output become a filesystem traversal.
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\") else { return [:] }
        let userHome = URL(fileURLWithPath: environment["ANDROID_USER_HOME"] ?? home.appendingPathComponent(".android").path)
        let emulatorHome = URL(fileURLWithPath: environment["ANDROID_EMULATOR_HOME"] ?? userHome.path)
        let roots = [environment["ANDROID_AVD_HOME"].map { URL(fileURLWithPath: $0) },
                     emulatorHome.appendingPathComponent("avd"), userHome.appendingPathComponent("avd"),
                     home.appendingPathComponent(".android/avd")].compactMap { $0 }
        for root in roots {
            let locatorURL = root.appendingPathComponent(name + ".ini")
            var directory = root.appendingPathComponent(name + ".avd")
            if let locator = try? String(contentsOf: locatorURL, encoding: .utf8) {
                let ini = parseINI(locator)
                if let absolute = ini["path"], absolute.hasPrefix("/") { directory = URL(fileURLWithPath: absolute) }
                else if let relative = ini["path.rel"] { directory = userHome.appendingPathComponent(relative) }
            }
            if let config = try? String(contentsOf: directory.appendingPathComponent("config.ini"), encoding: .utf8) {
                return parseINI(config)
            }
        }
        return [:]
    }

    public static func device(name: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> AndroidDevice {
        let values = avdConfig(name: name, environment: environment)
        let abi = values["abi.type"] ?? (["arm64", "aarch64"].contains(values["hw.cpu.arch"] ?? "") ? "arm64-v8a" : "unbekannt")
        let play = values["tag.id"] == "google_apis_playstore" || values["image.sysdir.1"]?.contains("google_apis_playstore") == true
        return AndroidDevice(name: name, abi: abi, googlePlay: play)
    }
}
