import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitDisplaySleepObserverController {
    public private(set) var currentSnapshot: DisplaySleepSnapshot?
    public private(set) var lastPublishedSnapshot: DisplaySleepSnapshot?

    private let publishStateDidChange: @MainActor (DisplaySleepSnapshot) -> Void

    public init(
        currentSnapshot: DisplaySleepSnapshot? = nil,
        publishStateDidChange: @escaping @MainActor (DisplaySleepSnapshot) -> Void = { _ in }
    ) {
        self.currentSnapshot = currentSnapshot
        self.publishStateDidChange = publishStateDidChange
    }

    public var eventName: String {
        DisplaySleepObserver.stateDidChangeEventName
    }

    @discardableResult
    public func observe(snapshot: DisplaySleepSnapshot) -> Bool {
        guard currentSnapshot != snapshot else {
            return false
        }

        currentSnapshot = snapshot
        lastPublishedSnapshot = snapshot
        publishStateDidChange(snapshot)
        return true
    }
}
