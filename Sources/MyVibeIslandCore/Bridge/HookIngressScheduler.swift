import Foundation

public final class HookIngressScheduler: @unchecked Sendable {
    private final class Lane {
        let queue: DispatchQueue
        var pendingCount = 0

        init(key: String) {
            queue = DispatchQueue(label: "my-vibe-island.hook-ingress.\(key)")
        }
    }

    private let lock = NSLock()
    private var lanes: [String: Lane] = [:]
    private let currentLaneKey = DispatchSpecificKey<ObjectIdentifier>()

    public init() {}

    public func perform<T>(for sessionKey: String?, _ body: () throws -> T) rethrows -> T {
        guard let sessionKey, !sessionKey.isEmpty else {
            return try body()
        }

        let lane = lock.withLock { () -> Lane in
            let lane = lanes[sessionKey] ?? Lane(key: sessionKey)
            lane.queue.setSpecific(key: currentLaneKey, value: ObjectIdentifier(lane))
            lane.pendingCount += 1
            lanes[sessionKey] = lane
            return lane
        }
        defer {
            lock.withLock {
                lane.pendingCount -= 1
                if lane.pendingCount == 0, lanes[sessionKey] === lane {
                    lanes.removeValue(forKey: sessionKey)
                }
            }
        }

        if DispatchQueue.getSpecific(key: currentLaneKey) == ObjectIdentifier(lane) {
            return try body()
        }
        return try lane.queue.sync(execute: body)
    }
}

extension BridgeEnvelope {
    var hookIngressSessionKey: String? {
        guard command == .hookEvent else { return nil }

        let rawSessionID: String?
        switch source {
        case "cursor":
            rawSessionID = payload.stringValue(for: "conversation_id")
        case "opencode":
            rawSessionID = payload.stringValue(for: "sessionID") ?? payload.stringValue(for: "sessionId")
        default:
            rawSessionID = payload.stringValue(for: "session_id") ?? payload.stringValue(for: "sessionId")
        }

        guard let rawSessionID else { return nil }
        return "\(source):\(rawSessionID)"
    }
}

private extension Dictionary where Key == String, Value == BridgeJSONValue {
    func stringValue(for key: String) -> String? {
        guard case let .string(value)? = self[key], !value.isEmpty else {
            return nil
        }
        return value
    }
}
