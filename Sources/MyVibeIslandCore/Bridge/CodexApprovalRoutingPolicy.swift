import Foundation

/// Routes a pending Codex approval using the modes and ownership behavior
/// observed in the original SocketServer runtime.
public enum CodexApprovalRoutingPolicy {
    public enum Ingress: Equatable, Sendable {
        case localBlocking
        case passiveTerminalHandoff
        case silentTerminalHandoff
    }

    public enum Route: Equatable, Sendable {
        case retainInIsland
        case handoffToTerminal
    }

    /// The visible permission surface is independent from the later bridge
    /// handoff decision. The captured default `approve_here` path retains
    /// native allow/deny controls; only the legacy terminal target routes to
    /// the terminal handoff presentation.
    public enum Presentation: Equatable, Sendable {
        case localResolution
        case terminalHandoff
    }

    public static func presentation(target: String?) -> Presentation {
        target == "terminal" ? .terminalHandoff : .localResolution
    }

    /// Labs' `codexApprovalMode` determines what happens when an id-less
    /// terminal-routed Codex request arrives. The older target cache is an
    /// explicit compatibility override and wins when present.
    public static func ingress(target: String?, mode: String?) -> Ingress {
        switch target {
        case "notch":
            return .localBlocking
        case "terminal":
            return .silentTerminalHandoff
        default:
            break
        }

        switch mode {
        case "hide":
            return .silentTerminalHandoff
        case "remind":
            return .passiveTerminalHandoff
        default:
            return .localBlocking
        }
    }

    public static func route(
        target: String?,
        owningTerminalIsFrontmost _: Bool,
        ownershipDeadlineExpired: Bool
    ) -> Route {
        switch target {
        case "notch":
            return .retainInIsland
        case "terminal":
            return .handoffToTerminal
        default:
            // The original keeps polling while the exact Terminal owner is
            // frontmost; only its ownership deadline performs the fallback.
            if ownershipDeadlineExpired {
                return .handoffToTerminal
            }
            return .retainInIsland
        }
    }
}
