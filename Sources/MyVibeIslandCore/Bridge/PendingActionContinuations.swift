import Foundation

public final class PendingActionContinuations: @unchecked Sendable {
    private struct Key: Hashable {
        let sessionId: String
        let requestId: String
    }

    private let timeout: TimeInterval
    private let condition = NSCondition()
    private var waiterCounts: [Key: Int] = [:]
    private var directives: [Key: BridgeJSONValue] = [:]
    private var cancelled: Set<Key> = []
    private var asyncWaiters: [Key: [UUID: @Sendable (BridgeJSONValue?) -> Void]] = [:]

    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    public func wait(for request: ActionableRequest) -> BridgeJSONValue? {
        wait(for: request, timeout: timeout)
    }

    public func wait(for request: ActionableRequest, timeout: TimeInterval) -> BridgeJSONValue? {
        register(for: request)
        return waitForRegistered(request, timeout: timeout)
    }

    func register(for request: ActionableRequest) {
        let key = Key(sessionId: request.sessionId, requestId: request.requestId)
        condition.lock()
        waiterCounts[key, default: 0] += 1
        let count = waiterCounts[key] ?? 0
        condition.unlock()
        SessionCompletionTraceLog.append(
            stage: "approval.continuation.register",
            sessionId: request.sessionId,
            metadata: [
                "requestId": request.requestId,
                "waiterCount": String(count),
            ]
        )
    }

    func waitForRegistered(_ request: ActionableRequest, timeout: TimeInterval) -> BridgeJSONValue? {
        let key = Key(sessionId: request.sessionId, requestId: request.requestId)
        let deadline = Date().addingTimeInterval(timeout)

        condition.lock()
        defer {
            if let count = waiterCounts[key], count > 1 {
                waiterCounts[key] = count - 1
            } else {
                waiterCounts.removeValue(forKey: key)
                directives.removeValue(forKey: key)
                cancelled.remove(key)
            }
            condition.unlock()
        }

        while directives[key] == nil {
            if cancelled.contains(key) {
                return nil
            }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                return nil
            }
            condition.wait(until: Date().addingTimeInterval(remaining))
        }
        let result = directives[key]
        SessionCompletionTraceLog.append(
            stage: "approval.continuation.wait_result",
            sessionId: request.sessionId,
            metadata: [
                "requestId": request.requestId,
                "resolved": String(result != nil),
                "cancelled": String(cancelled.contains(key)),
            ]
        )
        return result
    }

    /// Wait without occupying a thread. This is the transport path used by
    /// bridge clients whose hook process is allowed to remain connected while
    /// a local action is pending.
    public func waitForRegisteredAsync(
        _ request: ActionableRequest,
        timeout: TimeInterval,
        completion: @escaping @Sendable (BridgeJSONValue?) -> Void
    ) {
        let key = Key(sessionId: request.sessionId, requestId: request.requestId)
        let waiterID = UUID()

        condition.lock()
        if let directive = directives[key], !cancelled.contains(key) {
            condition.unlock()
            SessionCompletionTraceLog.append(
                stage: "approval.continuation.async_wait_result",
                sessionId: request.sessionId,
                metadata: ["requestId": request.requestId, "resolved": "true", "immediate": "true"]
            )
            completion(directive)
            return
        }
        if cancelled.contains(key) || waiterCounts[key] == nil {
            condition.unlock()
            SessionCompletionTraceLog.append(
                stage: "approval.continuation.async_wait_result",
                sessionId: request.sessionId,
                metadata: ["requestId": request.requestId, "resolved": "false", "reason": "not_pending"]
            )
            completion(nil)
            return
        }
        asyncWaiters[key, default: [:]][waiterID] = completion
        condition.unlock()

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finishAsyncWaiter(key: key, waiterID: waiterID)
        }
    }

    public var pendingCount: Int {
        condition.withLock { waiterCounts.values.reduce(0, +) }
    }

    /// A local action can only be resolved while its hook request is still
    /// blocked in this process. Persisted session metadata cannot recreate it.
    public func owns(_ request: ActionableRequest) -> Bool {
        let key = Key(sessionId: request.sessionId, requestId: request.requestId)
        return condition.withLock {
            waiterCounts[key] != nil && !cancelled.contains(key)
        }
    }

    @discardableResult
    public func cancel(sessionId: String, requestId: String) -> Bool {
        let key = Key(sessionId: sessionId, requestId: requestId)
        condition.lock()
        guard waiterCounts[key] != nil else {
            condition.unlock()
            return false
        }
        cancelled.insert(key)
        directives.removeValue(forKey: key)
        condition.broadcast()
        let waiterIDs = asyncWaiters[key].map { Array($0.keys) } ?? []
        condition.unlock()
        waiterIDs.forEach { finishAsyncWaiter(key: key, waiterID: $0) }
        return true
    }

    public func expire(sessionId: String, requestId: String) {
        cancel(sessionId: sessionId, requestId: requestId)
    }

    public func expire(sessionId: String) {
        condition.lock()
        let expired = waiterCounts.keys.filter { $0.sessionId == sessionId }
        cancelled.formUnion(expired)
        for key in expired {
            directives.removeValue(forKey: key)
        }
        condition.broadcast()
        let waiterIDs = expired.flatMap { key in
            (asyncWaiters[key].map { Array($0.keys) } ?? []).map { (key, $0) }
        }
        condition.unlock()
        waiterIDs.forEach { finishAsyncWaiter(key: $0.0, waiterID: $0.1) }
    }

    public func cancelAll() {
        condition.lock()
        cancelled.formUnion(waiterCounts.keys)
        directives.removeAll()
        condition.broadcast()
        let waiterIDs = asyncWaiters.flatMap { key, waiters in
            waiters.keys.map { (key, $0) }
        }
        condition.unlock()
        waiterIDs.forEach { finishAsyncWaiter(key: $0.0, waiterID: $0.1) }
    }

    @discardableResult
    public func resolve(sessionId: String, requestId: String, directive: BridgeJSONValue) -> Bool {
        let key = Key(sessionId: sessionId, requestId: requestId)

        condition.lock()
        guard waiterCounts[key] != nil else {
            condition.unlock()
            SessionCompletionTraceLog.append(
                stage: "approval.continuation.resolve",
                sessionId: sessionId,
                metadata: ["requestId": requestId, "resolved": "false", "reason": "no_waiter"]
            )
            return false
        }

        directives[key] = directive
        condition.broadcast()
        let waiterIDs = asyncWaiters[key].map { Array($0.keys) } ?? []
        condition.unlock()
        SessionCompletionTraceLog.append(
            stage: "approval.continuation.resolve",
            sessionId: sessionId,
            metadata: [
                "requestId": requestId,
                "resolved": "true",
                "asyncWaiterCount": String(waiterIDs.count),
            ]
        )
        waiterIDs.forEach { finishAsyncWaiter(key: key, waiterID: $0) }
        return true
    }

    private func finishAsyncWaiter(key: Key, waiterID: UUID) {
        condition.lock()
        guard let completion = asyncWaiters[key]?.removeValue(forKey: waiterID) else {
            condition.unlock()
            return
        }
        if asyncWaiters[key]?.isEmpty == true {
            asyncWaiters.removeValue(forKey: key)
        }
        let result = cancelled.contains(key) ? nil : directives[key]
        if let count = waiterCounts[key], count > 1 {
            waiterCounts[key] = count - 1
        } else {
            waiterCounts.removeValue(forKey: key)
            directives.removeValue(forKey: key)
            cancelled.remove(key)
        }
        condition.unlock()
        SessionCompletionTraceLog.append(
            stage: "approval.continuation.async_wait_result",
            sessionId: key.sessionId,
            metadata: [
                "requestId": key.requestId,
                "resolved": String(result != nil),
                "cancelled": String(result == nil),
            ]
        )
        completion(result)
    }
}
