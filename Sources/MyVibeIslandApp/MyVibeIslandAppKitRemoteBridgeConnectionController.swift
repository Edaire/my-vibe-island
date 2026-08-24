import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitRemoteBridgeConnectionController {
    public private(set) var connections: [RemoteBridgeConnection]
    public private(set) var lastPublishedConnections: [RemoteBridgeConnection]?

    private let publishConnections: @MainActor ([RemoteBridgeConnection]) -> Void

    public init(
        connections: [RemoteBridgeConnection] = [],
        publishConnections: @escaping @MainActor ([RemoteBridgeConnection]) -> Void = { _ in }
    ) {
        self.connections = connections.sorted { $0.connectionId < $1.connectionId }
        self.publishConnections = publishConnections
    }

    @discardableResult
    public func upsert(_ connection: RemoteBridgeConnection) -> [RemoteBridgeConnection] {
        var next = connections.filter { $0.connectionId != connection.connectionId }
        next.append(connection)
        connections = next.sorted { $0.connectionId < $1.connectionId }
        publishCurrentConnections()
        return connections
    }

    @discardableResult
    public func remove(connectionId: String) -> Bool {
        let next = connections.filter { $0.connectionId != connectionId }
        guard next.count != connections.count else {
            return false
        }

        connections = next
        publishCurrentConnections()
        return true
    }

    private func publishCurrentConnections() {
        lastPublishedConnections = connections
        publishConnections(connections)
    }
}
