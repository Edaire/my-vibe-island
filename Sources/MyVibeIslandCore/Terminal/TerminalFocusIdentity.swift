public enum TerminalFocusConfidence: String, Codable, Equatable, Sendable {
    case exact
    case strong
    case weak
    case unknown
}

public struct TerminalFocusIdentity: Codable, Equatable, Sendable {
    public let supacode: String?
    public let bundleId: String?
    public let processId: Int?
    public let windowId: String?
    public let tabId: String?
    public let paneId: String?
    public let tty: String?
    public let cwd: String?
    public let externalSessionId: String?
    public let confidence: TerminalFocusConfidence
    public let observedAt: String?

    public init(
        supacode: String? = nil,
        bundleId: String? = nil,
        processId: Int? = nil,
        windowId: String? = nil,
        tabId: String? = nil,
        paneId: String? = nil,
        tty: String? = nil,
        cwd: String? = nil,
        externalSessionId: String? = nil,
        confidence: TerminalFocusConfidence = .unknown,
        observedAt: String? = nil
    ) {
        self.supacode = TerminalModelNormalization.nonEmpty(supacode)
        self.bundleId = TerminalModelNormalization.nonEmpty(bundleId)
        self.processId = processId
        self.windowId = TerminalModelNormalization.nonEmpty(windowId)
        self.tabId = TerminalModelNormalization.nonEmpty(tabId)
        self.paneId = TerminalModelNormalization.nonEmpty(paneId)
        self.tty = TerminalModelNormalization.nonEmpty(tty)
        self.cwd = TerminalModelNormalization.nonEmpty(cwd)
        self.externalSessionId = TerminalModelNormalization.nonEmpty(externalSessionId)
        self.confidence = confidence
        self.observedAt = TerminalModelNormalization.nonEmpty(observedAt)
    }
}
