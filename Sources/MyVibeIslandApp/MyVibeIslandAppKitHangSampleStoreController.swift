import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitHangSampleStoreController {
    public private(set) var store: HangSampleStore
    public private(set) var lastPublishedStore: HangSampleStore?

    private let publishStore: @MainActor (HangSampleStore) -> Void

    public init(
        store: HangSampleStore = HangSampleStore(capacity: 8),
        publishStore: @escaping @MainActor (HangSampleStore) -> Void = { _ in }
    ) {
        self.store = store
        self.publishStore = publishStore
    }

    @discardableResult
    public func append(_ sample: MainThreadHangSnapshot) -> HangSampleStore {
        store.append(sample)
        lastPublishedStore = store
        publishStore(store)
        return store
    }
}
