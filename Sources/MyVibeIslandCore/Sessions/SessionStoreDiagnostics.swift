public struct SessionStoreDiagnostics: Equatable, Sendable {
    public let kind: String
    public let filePath: String?
    public let lastErrorDescription: String?
    public let sessionCount: Int

    public init(
        kind: String,
        filePath: String? = nil,
        lastErrorDescription: String? = nil,
        sessionCount: Int
    ) {
        self.kind = kind
        self.filePath = filePath
        self.lastErrorDescription = lastErrorDescription
        self.sessionCount = sessionCount
    }
}

public protocol SessionStoreDiagnosticsProviding: Sendable {
    func diagnostics() -> SessionStoreDiagnostics
}
