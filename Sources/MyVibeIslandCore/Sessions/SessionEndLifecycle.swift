import Foundation

public enum SessionEndLifecycle {
    // Measured from the V3 live Codex completion probe: the completed session
    // remains in the render registry for roughly two seconds after SessionEnd.
    public static let completionRetentionWindow: TimeInterval = 2
}

public protocol SessionEndCleanupScheduling: Sendable {
    func schedule(_ work: @escaping @Sendable () -> Void)
    func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void)
}

public extension SessionEndCleanupScheduling {
    func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void) {
        schedule(work)
    }
}

public struct MainActorSessionEndCleanupScheduler: SessionEndCleanupScheduling {
    public init() {}

    public func schedule(_ work: @escaping @Sendable () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    public func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void) {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, delay),
            execute: work
        )
    }
}

public struct SessionEndIntent: Equatable, Sendable {
    public let sessionId: String
    public let runtimeInstanceId: UUID
    public let lastActivityAt: Date
    public let status: SessionStatus
    public let hookIngressRevision: UInt64
    public let rawHookIngressCutoff: UInt64
    public let permissionIngressRevision: UInt64
    public let rawPermissionIngressCutoff: UInt64

    public init(
        sessionId: String,
        runtimeInstanceId: UUID,
        lastActivityAt: Date,
        status: SessionStatus,
        hookIngressRevision: UInt64,
        rawHookIngressCutoff: UInt64,
        permissionIngressRevision: UInt64,
        rawPermissionIngressCutoff: UInt64
    ) {
        self.sessionId = sessionId
        self.runtimeInstanceId = runtimeInstanceId
        self.lastActivityAt = lastActivityAt
        self.status = status
        self.hookIngressRevision = hookIngressRevision
        self.rawHookIngressCutoff = rawHookIngressCutoff
        self.permissionIngressRevision = permissionIngressRevision
        self.rawPermissionIngressCutoff = rawPermissionIngressCutoff
    }
}
