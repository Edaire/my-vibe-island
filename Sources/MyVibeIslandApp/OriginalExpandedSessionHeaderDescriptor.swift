import Foundation
import MyVibeIslandCore

struct OriginalExpandedSessionHeaderDescriptor: Equatable, Sendable {
    let title: String
    let prompt: String?
    let sourceLabel: String?
    let terminalLabel: String?
    let ageLabel: String?
    let processLabel: String?

    static func resolve(row: OriginalExpandedSessionRow, now: Date = Date()) -> Self {
        let session = row.session
        let jumpInput = session.jumpInput ?? session.resolvedJumpTarget?.input
        let workspace = normalized(
            session.cwd.isEmpty ? nil : URL(fileURLWithPath: session.cwd).lastPathComponent
        )
        let identity = normalized(row.preview.displayTitle)
            ?? normalized(session.source)
        let title = [workspace, identity]
            .compactMap { $0 }
            .joined(separator: " · ")

        let terminalLabel: String? = if jumpInput?.isInTmux == true || jumpInput?.tmuxPane != nil {
            "tmux"
        } else if let bundleID = jumpInput?.bundleId {
            bundleID.split(separator: ".").last.map(String.init)
        } else {
            nil
        }

        return Self(
            title: title.isEmpty ? session.id : title,
            prompt: normalized(session.lastUserMessage) ?? normalized(session.firstUserMessage),
            sourceLabel: normalized(session.source)?.capitalized,
            terminalLabel: terminalLabel,
            ageLabel: ageLabel(updatedAt: session.updatedAt, now: now),
            processLabel: nil
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private static func ageLabel(updatedAt: Date?, now: Date) -> String? {
        guard let updatedAt else { return nil }
        let seconds = now.timeIntervalSince(updatedAt)
        guard seconds >= 0, seconds < 86_400 else { return nil }
        if seconds < 60 { return "<1m" }
        return "\(Int(seconds / 60))m"
    }
}
