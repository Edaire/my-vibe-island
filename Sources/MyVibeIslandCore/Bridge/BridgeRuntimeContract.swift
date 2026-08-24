import Foundation

public enum BridgeRuntimeContract {
    public static let socketEnvironmentVariable = "VIBE_ISLAND_SOCKET"

    public static let originalProviderSources = [
        "claude",
        "codex",
        "zcode",
        "gemini",
        "antigravity",
        "cursor",
        "trae",
        "droid",
        "qoder",
        "qwen",
        "grok",
        "kimi",
        "kimicode",
        "deepseek",
        "mistralvibe",
        "copilot",
        "codebuddy",
        "workbuddy",
        "kiro",
        "hermes",
    ]

    public static let layers: [BridgeRuntimeLayer] = [
        .init(name: "CLI Entry", evidence: ["--source", "--event", "--integrity-check"]),
        .init(name: "Provider Handlers", evidence: originalProviderSources),
        .init(name: "Input Collectors", evidence: ["stdin hook JSON", "environment variables", "cwd", "transcript", "sqlite", "keychain"]),
        .init(name: "Context Enrichment", evidence: ["terminal identity", "tmux", "zellij", "warp", "iterm", "wezterm", "admission evidence"]),
        .init(name: "Normalized Payload", evidence: ["session id", "source", "event name", "cwd", "model", "tool", "transcript path", "terminal metadata"]),
        .init(name: "Socket Transport", evidence: ["VIBE_ISLAND_SOCKET", "~/.vibe-island/run/vibe-island.sock", "fire-and-forget", "waitForResponse", "ack"]),
    ]

    public static func defaultSocketPath(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        homeDirectory
            .appendingPathComponent(".my-vibe-island/run/my-vibe-island.sock")
            .path
    }
}

public struct BridgeRuntimeLayer: Equatable, Sendable {
    public let name: String
    public let evidence: [String]
}
