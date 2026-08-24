public struct ProcessOnlyAgentCorrelationHint: Codable, Equatable, Sendable {
    public let kind: String
    public let value: String

    public init(kind: String, value: String) {
        self.kind = kind
        self.value = value
    }
}

public struct ProcessOnlyAgentCandidate: Codable, Equatable, Sendable {
    public let source: String
    public let sessionId: String?
    public let pid: Int
    public let tty: String?
    public let cwd: String?
    public let bundleIdentifier: String?
    public let command: String?
    public let processName: String?
    public let executablePath: String?
    public let detectedAgentKind: String?
    public let confidence: Double
    public let observedAt: String?

    public init(
        source: String,
        sessionId: String? = nil,
        pid: Int,
        tty: String? = nil,
        cwd: String? = nil,
        bundleIdentifier: String? = nil,
        command: String? = nil,
        processName: String? = nil,
        executablePath: String? = nil,
        detectedAgentKind: String? = nil,
        confidence: Double = 0.5,
        observedAt: String? = nil
    ) {
        self.source = source
        self.sessionId = sessionId
        self.pid = pid
        self.tty = tty
        self.cwd = cwd
        self.bundleIdentifier = bundleIdentifier
        self.command = command
        self.processName = processName
        self.executablePath = executablePath
        self.detectedAgentKind = detectedAgentKind
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.observedAt = observedAt
    }

    public var isDetectedOnly: Bool {
        true
    }

    public var canCreateSessionWithoutCorrelation: Bool {
        false
    }

    public var correlationHints: [ProcessOnlyAgentCorrelationHint] {
        [
            hint(kind: "bundleIdentifier", value: bundleIdentifier),
            hint(kind: "cwd", value: cwd),
            ProcessOnlyAgentCorrelationHint(kind: "pid", value: String(pid)),
            hint(kind: "sessionId", value: sessionId),
            hint(kind: "source", value: source),
            hint(kind: "tty", value: tty)
        ].compactMap { $0 }
            .sorted { lhs, rhs in
                if lhs.kind == rhs.kind {
                    return lhs.value < rhs.value
                }
                return lhs.kind < rhs.kind
            }
    }

    private func hint(kind: String, value: String?) -> ProcessOnlyAgentCorrelationHint? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return ProcessOnlyAgentCorrelationHint(kind: kind, value: value)
    }
}
