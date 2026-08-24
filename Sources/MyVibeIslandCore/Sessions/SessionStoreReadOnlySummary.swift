import Foundation

/// Read-only diagnostic projection of the authoritative session store.
///
/// This deliberately does not inspect processes, terminals, or transcripts:
/// those observations cannot admit sessions into the render list.
public struct SessionStoreReadOnlySummary: Equatable, Sendable {
    public let sessionCount: Int
    public let sourceCounts: [String: Int]
    public let sessionIDs: [String]

    fileprivate init(
        sessionCount: Int,
        sourceCounts: [String: Int],
        sessionIDs: [String]
    ) {
        self.sessionCount = sessionCount
        self.sourceCounts = sourceCounts
        self.sessionIDs = sessionIDs
    }
}

public struct SessionStoreReadOnlySummaryReader: Sendable {
    private let store: SessionStore

    public init(store: SessionStore) {
        self.store = store
    }

    public func read() -> SessionStoreReadOnlySummary {
        let sessions = store.loadSnapshot().sessions
        return SessionStoreReadOnlySummary(
            sessionCount: sessions.count,
            sourceCounts: Dictionary(grouping: sessions, by: \.source)
                .mapValues(\.count),
            sessionIDs: sessions.map(\.id).sorted()
        )
    }
}
