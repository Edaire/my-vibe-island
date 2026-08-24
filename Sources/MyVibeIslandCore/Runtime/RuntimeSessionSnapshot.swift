public struct RuntimeSessionSnapshot: Equatable, Sendable {
    public let snapshot: SessionSnapshot
    public let isActive: Bool

    public init(snapshot: SessionSnapshot, isActive: Bool) {
        self.snapshot = snapshot
        self.isActive = isActive
    }
}
