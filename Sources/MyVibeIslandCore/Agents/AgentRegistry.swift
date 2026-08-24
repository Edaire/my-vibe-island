public struct AgentRegistry: Equatable, Sendable {
    public let descriptors: [AgentDescriptor]

    public init(descriptors: [AgentDescriptor]) {
        self.descriptors = descriptors
    }

    public func descriptor(for id: String) -> AgentDescriptor? {
        descriptors.first { $0.id == id }
    }

    public static let `default` = AgentRegistry(descriptors: [
        AgentDescriptor(
            id: "claude",
            displayName: "Claude Code",
            supportLevel: .supported,
            defaultEventSources: ["hooks", "transcriptDiscovery", "statusLine"]
        ),
        AgentDescriptor(
            id: "codex",
            displayName: "Codex CLI",
            supportLevel: .supported,
            defaultEventSources: ["hooks", "sessionFiles", "rateLimitMetadata"]
        ),
        AgentDescriptor(
            id: "opencode",
            displayName: "OpenCode",
            supportLevel: .supported,
            defaultEventSources: ["jsPlugin", "sessionMetadata", "permissionEvents"]
        ),
        AgentDescriptor(
            id: "gemini",
            displayName: "Gemini CLI",
            supportLevel: .supported,
            defaultEventSources: ["hooks"]
        ),
        AgentDescriptor(
            id: "cursor",
            displayName: "Cursor",
            supportLevel: .supported,
            defaultEventSources: ["hooks", "transcriptMetadata", "workspaceJump"]
        ),
        AgentDescriptor(
            id: "kimi",
            displayName: "Kimi CLI",
            supportLevel: .experimental,
            defaultEventSources: ["claudeCompatibleHooks", "providerUsage"]
        ),
        AgentDescriptor(
            id: "claude-desktop",
            displayName: "Claude Desktop Code",
            supportLevel: .experimental,
            defaultEventSources: []
        ),
        AgentDescriptor(
            id: "codex-desktop",
            displayName: "Codex Desktop App",
            supportLevel: .experimental,
            defaultEventSources: []
        ),
        AgentDescriptor(
            id: "qwen",
            displayName: "Qwen Code",
            supportLevel: .supported,
            defaultEventSources: ["claudeCompatibleHooks"]
        ),
        AgentDescriptor(
            id: "qoder",
            displayName: "Qoder",
            supportLevel: .supported,
            defaultEventSources: ["claudeCompatibleHooks"]
        ),
        AgentDescriptor(
            id: "factory",
            displayName: "Factory",
            supportLevel: .supported,
            defaultEventSources: ["claudeCompatibleHooks"]
        ),
        AgentDescriptor(
            id: "codebuddy",
            displayName: "CodeBuddy",
            supportLevel: .supported,
            defaultEventSources: ["claudeCompatibleHooks"]
        ),
        AgentDescriptor(
            id: "hermes",
            displayName: "Hermes Agent",
            supportLevel: .supported,
            defaultEventSources: ["pluginLifecycleHooks"]
        )
    ])
}
