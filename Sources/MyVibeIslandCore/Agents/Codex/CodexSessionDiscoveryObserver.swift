import CoreServices
import Dispatch
import Foundation

public protocol CodexSessionDiscoveryObserving: Sendable {
    func observe(
        roots: [URL],
        handler: @escaping @Sendable () -> Void
    ) -> CodexSessionWatchCancellation
}

public struct NoopCodexSessionDiscoveryObserver: CodexSessionDiscoveryObserving {
    public init() {}

    public func observe(
        roots _: [URL],
        handler _: @escaping @Sendable () -> Void
    ) -> CodexSessionWatchCancellation {
        NoopCodexSessionWatchCancellation()
    }
}

public final class FSEventsCodexSessionDiscoveryObserver: CodexSessionDiscoveryObserving, @unchecked Sendable {
    private let queue: DispatchQueue

    public init(queue: DispatchQueue = DispatchQueue(label: "my-vibe-island.codex-session-discovery")) {
        self.queue = queue
    }

    public func observe(
        roots: [URL],
        handler: @escaping @Sendable () -> Void
    ) -> CodexSessionWatchCancellation {
        guard !roots.isEmpty else {
            return NoopCodexSessionWatchCancellation()
        }

        let relay = FSEventsCodexSessionDiscoveryRelay(handler: handler)
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(relay).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            codexSessionDiscoveryFSEventCallback,
            &context,
            roots.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        ) else {
            return NoopCodexSessionWatchCancellation()
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return NoopCodexSessionWatchCancellation()
        }
        return FSEventsCodexSessionWatchCancellation(stream: stream, relay: relay)
    }
}

private final class FSEventsCodexSessionDiscoveryRelay: @unchecked Sendable {
    private let handler: @Sendable () -> Void

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func notify() {
        handler()
    }
}

private let codexSessionDiscoveryFSEventCallback: FSEventStreamCallback = { _, context, _, _, _, _ in
    guard let context else { return }
    Unmanaged<FSEventsCodexSessionDiscoveryRelay>
        .fromOpaque(context)
        .takeUnretainedValue()
        .notify()
}

private final class FSEventsCodexSessionWatchCancellation: CodexSessionWatchCancellation, @unchecked Sendable {
    private let lock = NSLock()
    private var stream: FSEventStreamRef?
    private var relay: FSEventsCodexSessionDiscoveryRelay?

    init(stream: FSEventStreamRef, relay: FSEventsCodexSessionDiscoveryRelay) {
        self.stream = stream
        self.relay = relay
    }

    func cancel() {
        lock.lock()
        let stream = self.stream
        self.stream = nil
        relay = nil
        lock.unlock()

        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    deinit {
        cancel()
    }
}

private final class NoopCodexSessionWatchCancellation: CodexSessionWatchCancellation, @unchecked Sendable {
    func cancel() {}
}
