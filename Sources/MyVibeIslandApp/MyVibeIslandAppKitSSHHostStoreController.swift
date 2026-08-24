import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHHostStoreController {
    public private(set) var store: SSHHostStore
    public private(set) var lastPublishedStore: SSHHostStore?

    private let loadStore: @MainActor () -> SSHHostStore
    private let publishStore: @MainActor (SSHHostStore) -> Void

    public init(
        store: SSHHostStore = SSHHostStore(),
        loadStore: @escaping @MainActor () -> SSHHostStore = { SSHHostStore() },
        publishStore: @escaping @MainActor (SSHHostStore) -> Void = { _ in }
    ) {
        self.store = store
        self.loadStore = loadStore
        self.publishStore = publishStore
    }

    @discardableResult
    public func refresh() -> SSHHostStore {
        replace(with: loadStore())
    }

    @discardableResult
    public func replace(with store: SSHHostStore) -> SSHHostStore {
        self.store = store
        lastPublishedStore = store
        publishStore(store)
        return store
    }
}
