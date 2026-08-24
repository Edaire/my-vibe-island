import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHReachabilityObserverController {
    public private(set) var currentObserver: SSHReachabilityObserver?
    public private(set) var lastPublishedObserver: SSHReachabilityObserver?

    private let publishReachabilityDidChange: @MainActor (SSHReachabilityObserver) -> Void

    public init(
        currentObserver: SSHReachabilityObserver? = nil,
        publishReachabilityDidChange: @escaping @MainActor (SSHReachabilityObserver) -> Void = { _ in }
    ) {
        self.currentObserver = currentObserver
        self.publishReachabilityDidChange = publishReachabilityDidChange
    }

    public var lastFailureKind: SSHTunnelFailureKind? {
        currentObserver?.lastProbeResult.failureKind
    }

    @discardableResult
    public func observe(_ observer: SSHReachabilityObserver) -> Bool {
        guard currentObserver != observer else {
            return false
        }

        currentObserver = observer
        lastPublishedObserver = observer
        publishReachabilityDidChange(observer)
        return true
    }
}
