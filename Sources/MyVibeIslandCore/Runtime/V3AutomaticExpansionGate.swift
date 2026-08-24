import Foundation

/// Foreground evidence consumed by the local projection of V3's automatic
/// task-completion expansion gate. It intentionally carries observations,
/// rather than inferring focus from a session's stored terminal identity.
public struct V3AutomaticExpansionFocus: Equatable, Sendable {
    public let frontmostBundleId: String?
    public let activeTTYs: Set<String>

    public init(frontmostBundleId: String?, activeTTYs: Set<String>) {
        self.frontmostBundleId = Self.nonEmpty(frontmostBundleId)
        self.activeTTYs = Set(activeTTYs.compactMap(Self.normalizedTTY))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    fileprivate static func normalizedTTY(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "?", trimmed != "??" else { return nil }
        return trimmed.hasPrefix("/dev/") ? String(trimmed.dropFirst(5)) : trimmed
    }
}

/// A local counterpart of the V3 automatic-expansion gate.
///
/// Foreground application identity is used for jump routing, but it must not
/// suppress completion presentation: the island exists to notify the user
/// while the terminal or browser is not focused. The gate therefore validates
/// that the session still has a concrete terminal target, while leaving focus
/// ownership to the presentation policy.
public struct V3AutomaticExpansionGate: Sendable {
    private let tmuxAttachmentProbe: @Sendable (String?, String?) -> TmuxClientAttachment?

    public init(
        tmuxAttachmentProbe: @escaping @Sendable (String?, String?) -> TmuxClientAttachment? = {
            TmuxClientAttachmentProbe().probe(socketPath: $0, pane: $1)
        }
    ) {
        self.tmuxAttachmentProbe = tmuxAttachmentProbe
    }

    public func allows(
        session: JumpInput,
        focus: V3AutomaticExpansionFocus
    ) -> Bool {
        _ = focus
        if session.isInTmux == true {
            guard let attachment = tmuxAttachmentProbe(session.tmuxSocketPath, session.tmuxPane),
                  attachment.hasAttachedClient else {
                return false
            }
            guard V3AutomaticExpansionFocus.normalizedTTY(attachment.clientTTY) != nil else {
                return false
            }
        } else {
            guard V3AutomaticExpansionFocus.normalizedTTY(session.tty) != nil else {
                return false
            }
        }
        // A completion is still eligible when another app is frontmost. The
        // target tty is evidence that the session is real; focus is not a
        // prerequisite for showing the notification.
        return true
    }
}
