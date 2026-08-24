public struct CodexSubagentMetadata: Codable, Equatable, Sendable {
    public let codexSubagentKind: String?
    public let codexSubagentParentThreadId: String?
    public let codexSubagentNickname: String?
    public let codexSubagentRole: String?
    public let source: String?
    public let rawEventId: String?

    public init(
        codexSubagentKind: String? = nil,
        codexSubagentParentThreadId: String? = nil,
        codexSubagentNickname: String? = nil,
        codexSubagentRole: String? = nil,
        source: String? = nil,
        rawEventId: String? = nil
    ) {
        self.codexSubagentKind = codexSubagentKind
        self.codexSubagentParentThreadId = codexSubagentParentThreadId
        self.codexSubagentNickname = codexSubagentNickname
        self.codexSubagentRole = codexSubagentRole
        self.source = source
        self.rawEventId = rawEventId
    }

    public var displayLabel: String {
        codexSubagentNickname.nonEmpty
            ?? codexSubagentRole.nonEmpty
            ?? codexSubagentKind.nonEmpty
            ?? "Subagent"
    }

    public var sidecarKey: String? {
        guard let source = source.nonEmpty, let rawEventId = rawEventId.nonEmpty else {
            return nil
        }

        return "\(source):\(rawEventId)"
    }

    public var isCodexSidecar: Bool {
        source == "codex" || source == nil
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self, !value.isEmpty else {
            return nil
        }

        return value
    }
}
