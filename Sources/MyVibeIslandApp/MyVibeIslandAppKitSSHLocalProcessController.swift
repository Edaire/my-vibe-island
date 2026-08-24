import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHLocalProcessController {
    public private(set) var rows: [SSHLocalProcessRow]
    public private(set) var identities: [SSHLocalClientIdentity]
    public private(set) var lastPublishedIdentities: [SSHLocalClientIdentity]?

    private let scanRows: @MainActor () -> [SSHLocalProcessRow]
    private let resolveIdentity: @MainActor (SSHLocalProcessRow) -> SSHLocalClientIdentity?
    private let publishIdentities: @MainActor ([SSHLocalClientIdentity]) -> Void

    public init(
        rows: [SSHLocalProcessRow] = [],
        identities: [SSHLocalClientIdentity] = [],
        scanRows: @escaping @MainActor () -> [SSHLocalProcessRow] = { [] },
        resolveIdentity: @escaping @MainActor (SSHLocalProcessRow) -> SSHLocalClientIdentity? = { _ in nil },
        publishIdentities: @escaping @MainActor ([SSHLocalClientIdentity]) -> Void = { _ in }
    ) {
        self.rows = rows
        self.identities = identities
        self.scanRows = scanRows
        self.resolveIdentity = resolveIdentity
        self.publishIdentities = publishIdentities
    }

    @discardableResult
    public func refresh() -> [SSHLocalClientIdentity] {
        rows = scanRows()
        identities = rows.compactMap(resolveIdentity)
        lastPublishedIdentities = identities
        publishIdentities(identities)
        return identities
    }
}
