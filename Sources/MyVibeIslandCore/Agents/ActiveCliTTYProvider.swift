import AppKit
import Foundation

public struct ActiveCliTTYProvider: Sendable {
    public static let terminalScript = """
    tell application "Terminal"
        if (count of windows) is 0 then return ""
        return tty of selected tab of front window
    end tell
    """

    public static let iTermScript = """
    tell application "iTerm2"
        if (count of windows) is 0 then return ""
        tell current window
            tell current tab
                tell current session
                    return tty
                end tell
            end tell
        end tell
    end tell
    """
    private let frontmostBundleIdentifier: @Sendable () -> String?
    private let runner: LocalProcessSnapshotRunning

    public init(
        frontmostBundleIdentifier: @escaping @Sendable () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        runner: LocalProcessSnapshotRunning? = nil
    ) {
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.runner = runner ?? SystemLocalProcessSnapshotRunner()
    }

    public func activeTTYs() -> Set<String> {
        activeTTYs(for: [])
    }

    /// Returns only the TTY of the currently focused terminal tab. Tmux target
    /// resolution belongs to the completion gate because it must use the
    /// completing session's socket and pane at consumption time.
    public func activeTTYs(for _: [AgentSession]) -> Set<String> {
        var ttys = Set<String>()
        let script: String
        switch frontmostBundleIdentifier() {
        case "com.apple.Terminal":
            script = Self.terminalScript
        case "com.googlecode.iterm2":
            script = Self.iTermScript
        default:
            script = ""
        }

        if !script.isEmpty,
           let output = try? runner.run(
               executable: "/usr/bin/osascript",
               arguments: ["-e", script]
           ),
           let tty = normalizedTTY(output) {
            ttys.insert(tty)
        }

        return ttys
    }

    private func normalizedTTY(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized != "?", normalized != "??" else { return nil }
        return normalized.hasPrefix("/dev/") ? String(normalized.dropFirst(5)) : normalized
    }
}
