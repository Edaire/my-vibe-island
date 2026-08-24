import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHPortConflictController {
    public private(set) var lastConflict: SSHPortConflict?

    private let publishConflict: @MainActor (SSHPortConflict) -> Void

    public init(
        lastConflict: SSHPortConflict? = nil,
        publishConflict: @escaping @MainActor (SSHPortConflict) -> Void = { _ in }
    ) {
        self.lastConflict = lastConflict
        self.publishConflict = publishConflict
    }

    public var allowsAutomaticCleanup: Bool {
        lastConflict?.allowsAutomaticCleanup == true
    }

    public var failsClosed: Bool {
        lastConflict?.failsClosed == true
    }

    @discardableResult
    public func record(_ conflict: SSHPortConflict) -> SSHPortConflict {
        lastConflict = conflict
        publishConflict(conflict)
        return conflict
    }

    public func clear() {
        lastConflict = nil
    }
}
