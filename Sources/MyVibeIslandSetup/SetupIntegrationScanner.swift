import Foundation

public enum SetupConfigFormat: String, Sendable {
    case json
    case toml
    case pluginFile
    case pluginDirectory
}

public enum SetupIntegrationIssue: String, Sendable {
    case configMissing
    case configUnreadable
    case configMalformed
    case configConflict
    case hooksDetected
    case pluginMissing
    case pluginPresent
    case pluginUnmanaged
    case managed
    case managedStale
}

public struct SetupIntegrationSource: Sendable {
    public let id: String
    public let displayName: String
    public let relativePath: String
    public let format: SetupConfigFormat

    public init(id: String, displayName: String, relativePath: String, format: SetupConfigFormat) {
        self.id = id
        self.displayName = displayName
        self.relativePath = relativePath
        self.format = format
    }
}

public struct SetupIntegrationStatus: Sendable {
    public let sourceId: String
    public let displayName: String
    public let relativePath: String
    public let absolutePath: String
    public let exists: Bool
    public let readable: Bool
    public let malformed: Bool
    public let issues: [SetupIntegrationIssue]
}

public struct SetupIntegrationScanner: Sendable {
    public let sources: [SetupIntegrationSource]

    public init(sources: [SetupIntegrationSource] = SetupIntegrationScanner.defaultSources) {
        self.sources = sources
    }

    public func scan(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [SetupIntegrationStatus] {
        let pathPolicy = SetupHomePathPolicy(homeDirectory: homeDirectory)
        return sources.map { source in
            let rawURL = homeDirectory.appendingPathComponent(source.relativePath)
            let url: URL
            do {
                url = try pathPolicy.resolve(rawURL)
            } catch {
                return status(source: source, url: rawURL, exists: false, readable: false, malformed: false, issues: [.configUnreadable])
            }
            switch source.format {
            case .json:
                return scanJSON(source: source, url: url)
            case .toml:
                return scanTOML(source: source, url: url)
            case .pluginFile:
                return scanPluginFile(source: source, url: url)
            case .pluginDirectory:
                return scanPluginDirectory(source: source, url: url)
            }
        }
    }

    public static let defaultSources: [SetupIntegrationSource] = [
        .init(id: "claude", displayName: "Claude Code", relativePath: ".claude/settings.json", format: .json),
        .init(id: "qwen", displayName: "Qwen Code", relativePath: ".qwen/settings.json", format: .json),
        .init(id: "qoder", displayName: "Qoder", relativePath: ".qoder/settings.json", format: .json),
        .init(id: "factory", displayName: "Factory", relativePath: ".factory/settings.json", format: .json),
        .init(id: "codebuddy", displayName: "CodeBuddy", relativePath: ".codebuddy/settings.json", format: .json),
        .init(id: "codex", displayName: "Codex CLI", relativePath: ".codex/hooks.json", format: .json),
        .init(id: "cursor", displayName: "Cursor", relativePath: ".cursor/hooks.json", format: .json),
        .init(id: "gemini", displayName: "Gemini CLI", relativePath: ".gemini/settings.json", format: .json),
        .init(id: "kimi", displayName: "Kimi CLI", relativePath: ".kimi/config.toml", format: .toml),
        .init(id: "opencode", displayName: "OpenCode plugin", relativePath: ".config/opencode/plugins/open-island.js", format: .pluginFile),
        .init(id: "hermes", displayName: "Hermes Agent plugin", relativePath: ".hermes/plugins/vibe-island", format: .pluginDirectory),
    ]

    private func scanJSON(source: SetupIntegrationSource, url: URL) -> SetupIntegrationStatus {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return status(source: source, url: url, exists: false, readable: false, malformed: false, issues: [.configMissing])
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return status(source: source, url: url, exists: true, readable: false, malformed: false, issues: [.configUnreadable])
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let config = try ManagedJSONHookConfig(data: data)
            let object = json as? [String: Any]
            let hooks = object?["hooks"] as? [String: Any]
            let managedEntries = hooks?.values.compactMap { $0 as? [[String: Any]] }.flatMap { $0 }.filter { ($0["managedBy"] as? String) == ManagedJSONHookConfig.marker } ?? []
            if managedEntries.contains(where: { ($0["source"] as? String) != source.id }) {
                return status(source: source, url: url, exists: true, readable: true, malformed: false, issues: [.configConflict])
            }
            let canonical = config.verify(
                sourceId: source.id,
                events: SetupInstaller.canonicalEvents(for: source.id),
                helperCommand: SetupInstaller.helperCommand(for: source.id),
                version: SetupInstaller.manifestVersion,
                usesCodexHookGroups: source.id == "codex"
            )
            let hasManagedHooks = !managedEntries.isEmpty
            let hasHooks = hooks != nil
            return status(source: source, url: url, exists: true, readable: true, malformed: false, issues: hasManagedHooks ? [canonical ? .managed : .managedStale] : (hasHooks ? [.hooksDetected] : []))
        } catch ManagedHookConfigError.unmanagedConflict {
            return status(source: source, url: url, exists: true, readable: true, malformed: false, issues: [.configConflict])
        } catch {
            return status(source: source, url: url, exists: true, readable: true, malformed: true, issues: [.configMalformed])
        }
    }

    private func scanTOML(source: SetupIntegrationSource, url: URL) -> SetupIntegrationStatus {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return status(source: source, url: url, exists: false, readable: false, malformed: false, issues: [.configMissing])
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            _ = try ManagedTOMLHookConfig(contents: content)
            let managed = content.contains(ManagedTOMLHookConfig.kimiBeginPrefix) && content.contains(ManagedTOMLHookConfig.endMarker)
            let canonical = try ManagedTOMLHookConfig(contents: content).verify(
                sourceId: source.id,
                events: SetupInstaller.canonicalEvents(for: source.id),
                helperCommand: SetupInstaller.helperCommand(for: source.id),
                version: SetupInstaller.manifestVersion
            )
            return status(source: source, url: url, exists: true, readable: true, malformed: false, issues: managed ? [canonical ? .managed : .managedStale] : (content.contains("[[hooks]]") ? [.hooksDetected] : []))
        } catch ManagedHookConfigError.unmanagedConflict {
            return status(source: source, url: url, exists: true, readable: true, malformed: false, issues: [.configConflict])
        } catch ManagedHookConfigError.malformed {
            return status(source: source, url: url, exists: true, readable: true, malformed: true, issues: [.configMalformed])
        } catch {
            return status(source: source, url: url, exists: true, readable: false, malformed: false, issues: [.configUnreadable])
        }
    }

    private func scanPluginFile(source: SetupIntegrationSource, url: URL) -> SetupIntegrationStatus {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return status(source: source, url: url, exists: false, readable: false, malformed: false, issues: [.pluginMissing])
        }
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let owned = contents.contains("MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN")
            let canonical = contents.contains("MY_VIBE_ISLAND_MANAGED_OPENCODE_PLUGIN v\(SetupInstaller.manifestVersion)") &&
                SetupInstaller.canonicalEvents(for: source.id).allSatisfy(contents.contains)
            return status(
                source: source,
                url: url,
                exists: true,
                readable: true,
                malformed: false,
                issues: [owned ? (canonical ? .managed : .managedStale) : .pluginUnmanaged]
            )
        } catch {
            return status(source: source, url: url, exists: true, readable: false, malformed: false, issues: [.configUnreadable])
        }
    }

    private func scanPluginDirectory(source: SetupIntegrationSource, url: URL) -> SetupIntegrationStatus {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return status(source: source, url: url, exists: false, readable: false, malformed: false, issues: [.pluginMissing])
        }
        let manifestURL = url.appendingPathComponent("plugin.yaml")
        let moduleURL = url.appendingPathComponent("__init__.py")
        do {
            let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
            let module = try String(contentsOf: moduleURL, encoding: .utf8)
            let owned = module.contains(HermesPluginTemplate.marker)
            let canonical = manifest == HermesPluginTemplate.manifest && module == HermesPluginTemplate.module
            return status(
                source: source,
                url: url,
                exists: true,
                readable: true,
                malformed: false,
                issues: [owned ? (canonical ? .managed : .managedStale) : .pluginUnmanaged]
            )
        } catch {
            return status(source: source, url: url, exists: true, readable: false, malformed: false, issues: [.configUnreadable])
        }
    }

    private func status(
        source: SetupIntegrationSource,
        url: URL,
        exists: Bool,
        readable: Bool,
        malformed: Bool,
        issues: [SetupIntegrationIssue]
    ) -> SetupIntegrationStatus {
        SetupIntegrationStatus(
            sourceId: source.id,
            displayName: source.displayName,
            relativePath: source.relativePath,
            absolutePath: url.path,
            exists: exists,
            readable: readable,
            malformed: malformed,
            issues: issues
        )
    }
}
