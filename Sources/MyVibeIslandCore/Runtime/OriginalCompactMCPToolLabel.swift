import Foundation

public enum OriginalCompactMCPToolLabel {
    public static func resolve(_ tool: String) -> String? {
        guard tool.hasPrefix("mcp__") else { return nil }

        let parts = tool
            .dropFirst(5)
            .components(separatedBy: "__")
            .filter { !$0.isEmpty }

        guard parts.count >= 2 else { return "MCP: \(tool)" }

        var server = parts[0]
        if server.hasPrefix("plugin_") {
            server = server.split(separator: "_").last.map(String.init) ?? server
        }

        return "\(server): \(parts[1])"
    }
}
