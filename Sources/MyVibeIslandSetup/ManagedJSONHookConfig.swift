import Foundation

public enum ManagedHookConfigError: Error, Equatable, LocalizedError {
    case malformed
    case unmanagedConflict
    case missingManagedConfiguration

    public var errorDescription: String? {
        switch self {
        case .malformed: return "managed hook configuration is malformed"
        case .unmanagedConflict: return "managed hook configuration has an unmanaged conflict"
        case .missingManagedConfiguration: return "managed hook configuration is missing"
        }
    }
}

public struct ManagedJSONHookConfig {
    public static let marker = "my-vibe-island"

    private var object: [String: Any]

    public init(data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ManagedHookConfigError.malformed
        }
        if let hooks = object["hooks"] {
            guard let hooks = hooks as? [String: Any] else { throw ManagedHookConfigError.malformed }
            for value in hooks.values where !(value is [[String: Any]]) { throw ManagedHookConfigError.malformed }
        }
        self.object = object
    }

    public func install(
        sourceId: String,
        events: [String],
        helperCommand: String,
        version: Int = 1,
        usesCodexHookGroups: Bool = false
    ) throws -> Data {
        var result = object
        var hooks = (result["hooks"] as? [String: Any]) ?? [:]
        let expected = Set(events)
        let usesClaudeHookGroups = sourceId == "claude"
        for (event, value) in hooks {
            guard var entries = value as? [[String: Any]] else { throw ManagedHookConfigError.malformed }
            if usesClaudeHookGroups {
                if entries.contains(where: { isManaged($0) && !ownedBy($0, sourceId: sourceId) }) {
                    throw ManagedHookConfigError.unmanagedConflict
                }
            } else if expected.contains(event), entries.contains(where: { !ownedBy($0, sourceId: sourceId) }) {
                throw ManagedHookConfigError.unmanagedConflict
            }
            entries.removeAll { ownedBy($0, sourceId: sourceId) }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
        }
        for event in events {
            let managedEntry = entry(
                sourceId: sourceId,
                event: event,
                helperCommand: helperCommand,
                version: version,
                usesCodexHookGroups: usesCodexHookGroups,
                usesClaudeHookGroups: usesClaudeHookGroups
            )
            if usesClaudeHookGroups {
                var entries = (hooks[event] as? [[String: Any]]) ?? []
                entries.append(managedEntry)
                hooks[event] = entries
            } else {
                hooks[event] = [managedEntry]
            }
        }
        result["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    }

    public func uninstall(sourceId: String, helperCommand: String) throws -> Data {
        var result = object
        guard var hooks = result["hooks"] as? [String: Any] else { return try encoded(result) }
        for (event, value) in hooks {
            guard var entries = value as? [[String: Any]] else { throw ManagedHookConfigError.malformed }
            if entries.contains(where: { isManaged($0) && (($0["source"] as? String) != sourceId) }) {
                throw ManagedHookConfigError.unmanagedConflict
            }
            entries.removeAll { ownedBy($0, sourceId: sourceId) }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
        }
        if hooks.isEmpty {
            result.removeValue(forKey: "hooks")
        } else {
            result["hooks"] = hooks
        }
        return try encoded(result)
    }

    public func verify(
        sourceId: String,
        events: [String],
        helperCommand: String,
        version: Int = 1,
        usesCodexHookGroups: Bool = false
    ) -> Bool {
        guard let hooks = object["hooks"] as? [String: Any] else { return false }
        let expected = Set(events)
        let usesClaudeHookGroups = sourceId == "claude"
        guard events.allSatisfy({ event in
            guard let entries = hooks[event] as? [[String: Any]] else { return false }
            let managedEntries = entries.filter { ownedBy($0, sourceId: sourceId) }
            let entriesToVerify = usesClaudeHookGroups ? managedEntries : entries
            return entriesToVerify.count == 1 && entriesToVerify.allSatisfy {
                matches(
                    $0,
                    sourceId: sourceId,
                    event: event,
                    helperCommand: helperCommand,
                    version: version,
                    usesCodexHookGroups: usesCodexHookGroups,
                    usesClaudeHookGroups: usesClaudeHookGroups
                )
            }
        }) else { return false }
        return hooks.allSatisfy { event, value in
            guard let entries = value as? [[String: Any]] else { return false }
            return entries.filter { ownedBy($0, sourceId: sourceId) }.allSatisfy { entry in
                expected.contains(event) && matches(
                    entry,
                    sourceId: sourceId,
                    event: event,
                    helperCommand: helperCommand,
                    version: version,
                    usesCodexHookGroups: usesCodexHookGroups,
                    usesClaudeHookGroups: usesClaudeHookGroups
                )
            }
        }
    }

    private func entry(
        sourceId: String,
        event: String,
        helperCommand: String,
        version: Int,
        usesCodexHookGroups: Bool,
        usesClaudeHookGroups: Bool
    ) -> [String: Any] {
        if usesCodexHookGroups {
            var group: [String: Any] = [
                "hooks": [[
                    "type": "command",
                    "command": "\(helperCommand) --source codex",
                    "timeout": codexTimeout(for: event)
                ]],
                "managedBy": Self.marker,
                "source": sourceId,
                "version": version
            ]
            if event == "SessionStart" {
                group["matcher"] = "startup|resume|clear"
            } else if event == "PostToolUse" {
                group["matcher"] = ""
            }
            return group
        }
        if usesClaudeHookGroups {
            var command: [String: Any] = [
                "type": "command",
                "command": "\(helperCommand) --source \(sourceId)",
            ]
            if let timeout = claudeTimeout(for: event) {
                command["timeout"] = timeout
            }
            var group: [String: Any] = [
                "hooks": [command],
                "managedBy": Self.marker,
                "source": sourceId,
                "version": version,
            ]
            if let matcher = claudeMatcher(for: event) {
                group["matcher"] = matcher
            }
            return group
        }
        return [
            "type": "command",
            "command": "\(helperCommand) --source \(sourceId) --event \(event)",
            "managedBy": Self.marker,
            "source": sourceId,
            "version": version
        ]
    }

    private func isManaged(_ entry: [String: Any]) -> Bool { entry["managedBy"] as? String == Self.marker }

    private func ownedBy(_ entry: [String: Any], sourceId: String) -> Bool {
        isManaged(entry) && (entry["source"] as? String) == sourceId
    }

    private func matches(
        _ entry: [String: Any],
        sourceId: String,
        event: String,
        helperCommand: String,
        version: Int,
        usesCodexHookGroups: Bool,
        usesClaudeHookGroups: Bool
    ) -> Bool {
        if usesCodexHookGroups {
            guard isManaged(entry),
                  (entry["source"] as? String) == sourceId,
                  number(entry["version"]) == version,
                  let nested = entry["hooks"] as? [[String: Any]],
                  nested.count == 1,
                  nested[0]["type"] as? String == "command",
                  nested[0]["command"] as? String == "\(helperCommand) --source codex",
                  number(nested[0]["timeout"]) == codexTimeout(for: event) else {
                return false
            }
            let expectedMatcher: String? = event == "SessionStart" ? "startup|resume|clear" : (event == "PostToolUse" ? "" : nil)
            return (entry["matcher"] as? String) == expectedMatcher
        }
        if usesClaudeHookGroups {
            guard isManaged(entry),
                  (entry["source"] as? String) == sourceId,
                  number(entry["version"]) == version,
                  let nested = entry["hooks"] as? [[String: Any]],
                  nested.count == 1,
                  nested[0]["type"] as? String == "command",
                  nested[0]["command"] as? String == "\(helperCommand) --source \(sourceId)",
                  number(nested[0]["timeout"]) == claudeTimeout(for: event) else {
                return false
            }
            return (entry["matcher"] as? String) == claudeMatcher(for: event)
        }
        return isManaged(entry) && (entry["source"] as? String) == sourceId && number(entry["version"]) == version &&
            (entry["command"] as? String) == "\(helperCommand) --source \(sourceId) --event \(event)"
    }

    private func codexTimeout(for event: String) -> Int {
        switch event {
        case "PermissionRequest":
            return 7200
        case "SessionEnd":
            return 1
        default:
            return 5
        }
    }

    private func claudeMatcher(for event: String) -> String? {
        switch event {
        case "SessionStart": "startup|resume|clear"
        case "PreCompact": "manual|auto"
        case "PermissionRequest": "*"
        default: nil
        }
    }

    private func claudeTimeout(for event: String) -> Int? {
        event == "PermissionRequest" ? 86_400 : nil
    }

    private func number(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func encoded(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
}
