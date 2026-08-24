public struct OpenCodeSyncDiagnostics: Equatable, Sendable {
    public let rootPath: String
    public let attemptedFileCount: Int
    public let successfulSnapshotCount: Int
    public let failedSnapshotCount: Int
    public let emittedEventCount: Int
    public let rootMissing: Bool

    public init(
        rootPath: String,
        attemptedFileCount: Int,
        successfulSnapshotCount: Int,
        failedSnapshotCount: Int,
        emittedEventCount: Int,
        rootMissing: Bool
    ) {
        self.rootPath = rootPath
        self.attemptedFileCount = attemptedFileCount
        self.successfulSnapshotCount = successfulSnapshotCount
        self.failedSnapshotCount = failedSnapshotCount
        self.emittedEventCount = emittedEventCount
        self.rootMissing = rootMissing
    }
}
