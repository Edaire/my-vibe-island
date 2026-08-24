import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSoundOutputDeviceObserverController {
    public private(set) var currentSnapshot: SoundOutputDeviceSnapshot?
    public private(set) var lastChange: SoundOutputDeviceChange?

    private let observer: SoundOutputDeviceObserver
    private let publishChange: @MainActor (SoundOutputDeviceChange) -> Void

    public init(
        observer: SoundOutputDeviceObserver = SoundOutputDeviceObserver(),
        currentSnapshot: SoundOutputDeviceSnapshot? = nil,
        publishChange: @escaping @MainActor (SoundOutputDeviceChange) -> Void = { _ in }
    ) {
        self.observer = observer
        self.currentSnapshot = currentSnapshot
        self.publishChange = publishChange
    }

    @discardableResult
    public func observe(
        currentSnapshot newSnapshot: SoundOutputDeviceSnapshot?
    ) -> SoundOutputDeviceChange? {
        let change = observer.change(from: currentSnapshot, to: newSnapshot)
        currentSnapshot = newSnapshot

        guard let change else {
            return nil
        }

        lastChange = change
        publishChange(change)
        return change
    }
}
