import Foundation

/// Keeps the blocking Codex approval hook alive long enough for the island to
/// decide whether to approve locally or hand the request back to Terminal.
public struct CodexPermissionRequestTimeoutInstaller: Sendable {
    public static let permissionRequestTimeout = 7_200

    public let configURL: URL

    public init(configURL: URL) {
        self.configURL = configURL
    }

    public static func production(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> CodexPermissionRequestTimeoutInstaller {
        CodexPermissionRequestTimeoutInstaller(
            configURL: homeDirectory.appendingPathComponent(".codex/hooks.json")
        )
    }

    @discardableResult
    public func install(fileManager: FileManager = .default) throws -> Bool {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return false
        }

        let original = try Data(contentsOf: configURL)
        guard var root = try JSONSerialization.jsonObject(with: original) as? [String: Any],
              var hooksByEvent = root["hooks"] as? [String: Any],
              var permissionEntries = hooksByEvent["PermissionRequest"] as? [[String: Any]] else {
            return false
        }

        var changed = false
        for entryIndex in permissionEntries.indices {
            guard var entryHooks = permissionEntries[entryIndex]["hooks"] as? [[String: Any]] else {
                continue
            }
            for hookIndex in entryHooks.indices {
                guard isMyCodexHook(entryHooks[hookIndex]["command"] as? String) else {
                    continue
                }
                if numericValue(entryHooks[hookIndex]["timeout"]) != Self.permissionRequestTimeout {
                    entryHooks[hookIndex]["timeout"] = Self.permissionRequestTimeout
                    changed = true
                }
            }
            permissionEntries[entryIndex]["hooks"] = entryHooks
        }

        guard changed else {
            return false
        }

        hooksByEvent["PermissionRequest"] = permissionEntries
        root["hooks"] = hooksByEvent
        let updated = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try updated.write(to: configURL, options: .atomic)
        return true
    }

    private func isMyCodexHook(_ command: String?) -> Bool {
        guard let command else { return false }
        return command.contains(".my-vibe-island/bin/my-vibe-island-hooks")
            && command.contains("--source codex")
    }

    private func numericValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}
