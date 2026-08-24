public struct AppRuntimeStatus: Equatable, Sendable {
    public let socketPath: String
    public let isBridgeRunning: Bool
    public let sessionCount: Int
    public let sessionStoreDiagnostics: SessionStoreDiagnostics?
    public let openCodeSyncDiagnostics: OpenCodeSyncDiagnostics?

    public init(
        socketPath: String,
        isBridgeRunning: Bool,
        sessionCount: Int,
        sessionStoreDiagnostics: SessionStoreDiagnostics? = nil,
        openCodeSyncDiagnostics: OpenCodeSyncDiagnostics? = nil
    ) {
        self.socketPath = socketPath
        self.isBridgeRunning = isBridgeRunning
        self.sessionCount = sessionCount
        self.sessionStoreDiagnostics = sessionStoreDiagnostics
        self.openCodeSyncDiagnostics = openCodeSyncDiagnostics
    }
}
