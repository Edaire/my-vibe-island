import Foundation

public struct SetupInstallResult: Sendable {
    public let sourceId: String
    public let relativePath: String
    public let changed: Bool
    public let message: String

    public init(sourceId: String, relativePath: String, changed: Bool, message: String) {
        self.sourceId = sourceId
        self.relativePath = relativePath
        self.changed = changed
        self.message = message
    }
}

public enum SetupCLIError: Error, Equatable, LocalizedError {
    case verificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .verificationFailed(let sourceId): return "verification failed for \(sourceId)"
        }
    }
}

public struct SetupInstaller: Sendable {
    public static let helperCommand = "$HOME/.vibe-island/bin/vibe-island-bridge"
    public static let claudeHelperCommand = "$HOME/.my-vibe-island/bin/my-vibe-island-bridge"
    public static let codexHelperCommand = "$HOME/.my-vibe-island/bin/my-vibe-island-hooks"
    public static let hermesHelperCommand = "$HOME/.my-vibe-island/bin/my-vibe-island-bridge"
    public static let manifestVersion = 1

    public init() {}

    public static func helperCommand(for sourceId: String) -> String {
        switch sourceId {
        case "claude": claudeHelperCommand
        case "codex": codexHelperCommand
        case "hermes": hermesHelperCommand
        default: helperCommand
        }
    }

    public func status(sourceId: String, homeDirectory: URL) throws -> SetupIntegrationStatus {
        guard let status = SetupIntegrationScanner().scan(homeDirectory: homeDirectory).first(where: { $0.sourceId == sourceId }) else {
            throw SetupInstallerError.unknownSource(sourceId)
        }
        return status
    }

    public func install(sourceId: String, homeDirectory: URL) throws -> SetupInstallResult {
        let source = try source(for: sourceId)
        let events = Self.canonicalEvents(for: sourceId)
        let transaction = SetupMutationTransaction(homeDirectory: homeDirectory)

        do {
            switch source.format {
            case .pluginFile:
                return try installOpenCode(homeDirectory: homeDirectory, source: source, transaction: transaction)
            case .toml:
                return try installKimi(homeDirectory: homeDirectory, source: source, events: events, transaction: transaction)
            case .json:
                return try installJSON(homeDirectory: homeDirectory, source: source, events: events, transaction: transaction)
            case .pluginDirectory:
                return try installHermes(homeDirectory: homeDirectory, source: source, transaction: transaction)
            }
        } catch {
            transaction.rollback()
            throw error
        }
    }

    public func verify(sourceId: String, homeDirectory: URL) throws -> Bool {
        let source = try source(for: sourceId)
        let events = Self.canonicalEvents(for: sourceId)
        let url = try SetupHomePathPolicy(homeDirectory: homeDirectory).resolve(
            homeDirectory.appendingPathComponent(source.relativePath)
        )

        switch source.format {
        case .pluginFile:
            return try verifyOpenCode(at: url)
        case .toml:
            guard let data = try existingData(at: url) else { return false }
            return try ManagedTOMLHookConfig(contents: String(decoding: data, as: UTF8.self)).verify(
                sourceId: sourceId,
                events: events,
                helperCommand: Self.helperCommand(for: sourceId),
                version: Self.manifestVersion
            )
        case .json:
            guard let data = try existingData(at: url) else { return false }
            return try ManagedJSONHookConfig(data: data).verify(
                sourceId: sourceId,
                events: events,
                helperCommand: Self.helperCommand(for: sourceId),
                version: Self.manifestVersion,
                usesCodexHookGroups: sourceId == "codex"
            )
        case .pluginDirectory:
            return try verifyHermes(at: url)
        }
    }

    public func repair(sourceId: String, homeDirectory: URL) throws -> SetupInstallResult {
        if try verify(sourceId: sourceId, homeDirectory: homeDirectory) {
            let source = try source(for: sourceId)
            return result(source, changed: false, message: "\(source.displayName) is healthy")
        }
        return try install(sourceId: sourceId, homeDirectory: homeDirectory)
    }

    public func uninstall(sourceId: String, homeDirectory: URL) throws -> SetupInstallResult {
        let source = try source(for: sourceId)
        let transaction = SetupMutationTransaction(homeDirectory: homeDirectory)

        do {
            let url = try transaction.resolve(homeDirectory.appendingPathComponent(source.relativePath))
            switch source.format {
            case .pluginFile:
                return try uninstallOpenCode(at: url, source: source, transaction: transaction)
            case .toml:
                guard let original = try existingData(at: url) else {
                    return result(source, changed: false, message: "nothing to uninstall")
                }
                let updated = Data(try ManagedTOMLHookConfig(contents: String(decoding: original, as: UTF8.self)).uninstall().utf8)
                if updated != original { try writeTextMutation(updated, to: url, original: original, transaction: transaction) }
                return result(source, changed: updated != original, message: updated != original ? "uninstalled managed \(source.displayName)" : "nothing to uninstall")
            case .json:
                let manifestURL = homeDirectory.appendingPathComponent(SetupManifestStore.relativePath)
                _ = try transaction.validate([url, manifestURL])
                var changed = false
                if let original = try existingData(at: url) {
                    let updated = try ManagedJSONHookConfig(data: original).uninstall(
                        sourceId: sourceId,
                        helperCommand: Self.helperCommand(for: sourceId)
                    )
                    if updated != original {
                        try writeJSON(updated, to: url, original: original, transaction: transaction)
                        changed = true
                    }
                }
                try transaction.prepareExternalMutation(at: manifestURL)
                try SetupManifestStore(homeDirectory: homeDirectory).remove(sourceId: sourceId)
                return result(source, changed: changed, message: changed ? "uninstalled managed \(source.displayName)" : "nothing to uninstall")
            case .pluginDirectory:
                return try uninstallHermes(at: url, source: source, transaction: transaction)
            }
        } catch {
            transaction.rollback()
            throw error
        }
    }

    public static func canonicalEvents(for sourceId: String) -> [String] {
        switch sourceId {
        case "claude", "qwen", "qoder", "factory", "codebuddy":
            return ["UserPromptSubmit", "SessionStart", "SessionEnd", "Stop", "StopFailure", "SubagentStart", "SubagentStop", "Notification", "PreToolUse", "PermissionRequest", "PostToolUse", "PostToolUseFailure", "PermissionDenied", "PreCompact"].sorted()
        case "codex":
            return [
                "PermissionRequest",
                "PostToolUse",
                "SessionEnd",
                "SessionStart",
                "Stop",
                "SubagentStop",
                "UserPromptSubmit",
            ].sorted()
        case "cursor":
            return ["beforeSubmitPrompt", "beforeShellExecution", "beforeMCPExecution", "beforeReadFile", "afterFileEdit", "stop"].sorted()
        case "gemini":
            return ["SessionStart", "SessionEnd", "BeforeAgent", "AfterAgent", "Notification"].sorted()
        case "kimi":
            return ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "Notification"].sorted()
        case "opencode":
            return ["permission.asked", "question.asked"].sorted()
        case "hermes":
            return ["on_session_start", "on_session_end", "on_session_finalize", "pre_llm_call", "post_llm_call", "pre_tool_call", "post_tool_call"].sorted()
        default:
            return []
        }
    }

    private func installJSON(homeDirectory: URL, source: SetupIntegrationSource, events: [String], transaction: SetupMutationTransaction) throws -> SetupInstallResult {
        let rawURL = homeDirectory.appendingPathComponent(source.relativePath)
        let rawManifestURL = homeDirectory.appendingPathComponent(SetupManifestStore.relativePath)
        var paths = [rawURL, rawManifestURL]
        if source.id == "codex" { paths.append(homeDirectory.appendingPathComponent(".codex/config.toml")) }
        let resolved = try transaction.validate(paths)
        let url = resolved[0]
        let original = try existingData(at: url) ?? Data("{}".utf8)
        let installInput: Data
        if source.id == "codex" {
            installInput = try migratingLegacyCodexHooks(in: original)
        } else {
            installInput = original
        }
        let updated = try ManagedJSONHookConfig(data: installInput).install(
            sourceId: source.id,
            events: events,
            helperCommand: Self.helperCommand(for: source.id),
            version: Self.manifestVersion,
            usesCodexHookGroups: source.id == "codex"
        )
        var changed = original != updated
        if original != updated { try writeJSON(updated, to: url, original: existingDataForBackup(at: url, fallback: original), transaction: transaction) }

        if source.id == "codex" {
            let configURL = resolved[2]
            let configOriginal = try existingData(at: configURL)
            let contents = configOriginal.map { String(decoding: $0, as: UTF8.self) } ?? ""
            let configUpdated = Data(CodexTUIConfig(contents: contents).installingTerminalTitle().utf8)
            if configUpdated != configOriginal {
                try writeTextMutation(configUpdated, to: configURL, original: configOriginal, transaction: transaction)
                changed = true
            }
        }

        try transaction.prepareExternalMutation(at: rawManifestURL)
        try saveManifest(source: source, homeDirectory: homeDirectory, events: events)
        return result(source, changed: changed, message: changed ? "installed managed \(source.displayName)" : "\(source.displayName) already installed")
    }

    private func installKimi(homeDirectory: URL, source: SetupIntegrationSource, events: [String], transaction: SetupMutationTransaction) throws -> SetupInstallResult {
        let url = try transaction.resolve(homeDirectory.appendingPathComponent(source.relativePath))
        guard let original = try existingData(at: url) else {
            return result(source, changed: false, message: "Kimi config missing; no files changed")
        }
        let updated = Data(try ManagedTOMLHookConfig(contents: String(decoding: original, as: UTF8.self)).install(
            sourceId: source.id,
            events: events,
            helperCommand: Self.helperCommand(for: source.id),
            version: Self.manifestVersion
        ).utf8)
        if updated != original { try writeTextMutation(updated, to: url, original: original, transaction: transaction) }
        return result(source, changed: updated != original, message: updated != original ? "installed managed \(source.displayName)" : "\(source.displayName) already installed")
    }

    private func installOpenCode(homeDirectory: URL, source: SetupIntegrationSource, transaction: SetupMutationTransaction) throws -> SetupInstallResult {
        let url = try transaction.resolve(homeDirectory.appendingPathComponent(source.relativePath))
        if let original = try existingData(at: url) {
            let contents = String(decoding: original, as: UTF8.self)
            guard contents.contains("MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN") else {
                throw ManagedHookConfigError.unmanagedConflict
            }
            guard contents != OpenCodePluginTemplate.contents else {
                return result(source, changed: false, message: "\(source.displayName) already installed")
            }
            try writePlugin(to: url, transaction: transaction)
        } else {
            try writePlugin(to: url, transaction: transaction)
        }
        return result(source, changed: true, message: "installed managed \(source.displayName)")
    }

    private func verifyOpenCode(at url: URL) throws -> Bool {
        guard let data = try existingData(at: url) else { return false }
        let contents = String(decoding: data, as: UTF8.self)
        return contents.contains("MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN v\(Self.manifestVersion)") &&
            Self.canonicalEvents(for: "opencode").allSatisfy(contents.contains)
    }

    private func installHermes(homeDirectory: URL, source: SetupIntegrationSource, transaction: SetupMutationTransaction) throws -> SetupInstallResult {
        let directory = try transaction.resolve(homeDirectory.appendingPathComponent(source.relativePath))
        if FileManager.default.fileExists(atPath: directory.path), !(try verifyHermes(at: directory)) {
            let moduleURL = directory.appendingPathComponent("__init__.py")
            let module = try existingData(at: moduleURL).map { String(decoding: $0, as: UTF8.self) } ?? ""
            guard module.contains(HermesPluginTemplate.marker) else {
                throw ManagedHookConfigError.unmanagedConflict
            }
        }

        let manifestURL = directory.appendingPathComponent("plugin.yaml")
        let moduleURL = directory.appendingPathComponent("__init__.py")
        let oldManifest = try existingData(at: manifestURL)
        let oldModule = try existingData(at: moduleURL)
        try transaction.write(Data(HermesPluginTemplate.manifest.utf8), to: manifestURL)
        try transaction.write(Data(HermesPluginTemplate.module.utf8), to: moduleURL)
        let changed = oldManifest != Data(HermesPluginTemplate.manifest.utf8) || oldModule != Data(HermesPluginTemplate.module.utf8)
        return result(source, changed: changed, message: changed ? "installed managed \(source.displayName)" : "\(source.displayName) already installed")
    }

    private func verifyHermes(at directory: URL) throws -> Bool {
        guard let manifest = try existingData(at: directory.appendingPathComponent("plugin.yaml")),
              let module = try existingData(at: directory.appendingPathComponent("__init__.py")) else {
            return false
        }
        return String(decoding: manifest, as: UTF8.self) == HermesPluginTemplate.manifest &&
            String(decoding: module, as: UTF8.self) == HermesPluginTemplate.module
    }

    private func uninstallOpenCode(at url: URL, source: SetupIntegrationSource, transaction: SetupMutationTransaction) throws -> SetupInstallResult {
        guard let data = try existingData(at: url) else {
            return result(source, changed: false, message: "nothing to uninstall")
        }
        guard String(decoding: data, as: UTF8.self).contains("MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN") else {
            throw ManagedHookConfigError.unmanagedConflict
        }
        try transaction.remove(url)
        return result(source, changed: true, message: "uninstalled managed \(source.displayName)")
    }

    private func uninstallHermes(at directory: URL, source: SetupIntegrationSource, transaction: SetupMutationTransaction) throws -> SetupInstallResult {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return result(source, changed: false, message: "nothing to uninstall")
        }
        guard try verifyHermes(at: directory) else {
            throw ManagedHookConfigError.unmanagedConflict
        }
        try transaction.remove(directory)
        return result(source, changed: true, message: "uninstalled managed \(source.displayName)")
    }

    private func saveManifest(source: SetupIntegrationSource, homeDirectory: URL, events: [String]) throws {
        try SetupManifestStore(homeDirectory: homeDirectory).save(SetupManifest(
            helperBinaryPath: Self.helperCommand(for: source.id),
            managedBlockMarker: ManagedJSONHookConfig.marker,
            sourceId: source.id,
            eventNames: events,
            installedCommand: Self.helperCommand(for: source.id),
            configPath: source.relativePath,
            managedPaths: [source.relativePath],
            lastInstalledVersion: String(Self.manifestVersion)
        ))
    }

    private func source(for sourceId: String) throws -> SetupIntegrationSource {
        guard let source = SetupIntegrationScanner.defaultSources.first(where: { $0.id == sourceId }) else {
            throw SetupInstallerError.unknownSource(sourceId)
        }
        return source
    }

    private func existingData(at url: URL) throws -> Data? {
        FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    }

    /// Vibe Island's previous reconstructed builds registered an unmarked
    /// helper alongside the local hook. Both commands consume the same Codex
    /// event, so retain neither during the one-time migration. Unknown user
    /// hooks stay untouched and still use the normal fail-closed policy.
    private func migratingLegacyCodexHooks(in data: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ManagedHookConfigError.malformed
        }
        guard var hooks = root["hooks"] as? [String: Any] else {
            return data
        }

        for (event, value) in hooks {
            guard let entries = value as? [[String: Any]] else {
                throw ManagedHookConfigError.malformed
            }
            let retained = entries.compactMap(legacyCodexEntryRemoved(_:))
            if retained.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = retained
            }
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private func legacyCodexEntryRemoved(_ entry: [String: Any]) -> [String: Any]? {
        if isLegacyCodexBridgeCommand(entry["command"] as? String) {
            return nil
        }
        guard var nested = entry["hooks"] as? [[String: Any]] else {
            return entry
        }
        nested.removeAll { isLegacyCodexBridgeCommand($0["command"] as? String) }
        guard !nested.isEmpty else {
            return nil
        }
        var retained = entry
        retained["hooks"] = nested
        return retained
    }

    private func isLegacyCodexBridgeCommand(_ command: String?) -> Bool {
        guard let command, command.contains("--source codex") else {
            return false
        }
        return command.contains(".vibe-island/bin/vibe-island-bridge")
            || command.contains(".my-vibe-island/bin/my-vibe-island-hooks")
    }

    private func existingDataForBackup(at url: URL, fallback: Data) -> Data? {
        FileManager.default.fileExists(atPath: url.path) ? fallback : nil
    }

    private func writeJSON(_ data: Data, to url: URL, original: Data?, transaction: SetupMutationTransaction) throws {
        if let original, !FileManager.default.fileExists(atPath: url.path + ".bak") {
            try transaction.write(original, to: URL(fileURLWithPath: url.path + ".bak"))
        }
        try transaction.write(data, to: url)
    }

    private func writePlugin(to url: URL, transaction: SetupMutationTransaction) throws {
        try transaction.write(Data(OpenCodePluginTemplate.contents.utf8), to: url)
    }

    private func writeTextMutation(_ data: Data, to url: URL, original: Data?, transaction: SetupMutationTransaction) throws {
        if let original {
            let canonicalBackup = URL(fileURLWithPath: url.path + ".backup")
            if !FileManager.default.fileExists(atPath: canonicalBackup.path) {
                try transaction.write(original, to: canonicalBackup)
            }
            try transaction.write(original, to: URL(fileURLWithPath: url.path + ".backup." + Self.uniqueBackupName()))
        }
        try transaction.write(data, to: url)
    }

    private static func uniqueBackupName() -> String {
        "\(Int(Date().timeIntervalSince1970 * 1_000_000_000))-\(UUID().uuidString)"
    }

    private func result(_ source: SetupIntegrationSource, changed: Bool, message: String) -> SetupInstallResult {
        SetupInstallResult(sourceId: source.id, relativePath: source.relativePath, changed: changed, message: message)
    }
}

public enum SetupInstallerError: Error, Equatable, LocalizedError {
    case unknownSource(String)

    public var errorDescription: String? {
        switch self {
        case .unknownSource(let sourceId): return "unknown setup source: \(sourceId)"
        }
    }
}
