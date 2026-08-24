import Darwin
import Foundation

public final class BridgeServer: @unchecked Sendable {
    private static let hardFrameByteLimit = 1_048_576
    private static let hardConcurrentClientLimit = 64

    private let socketPath: String
    private let handler: BridgeRequestHandler
    private let codec: BridgeCodec
    private let frameByteLimit: Int
    private let maxConcurrentClients: Int
    private let queue = DispatchQueue(label: "my-vibe-island.bridge-server")
    private let connectionQueue = DispatchQueue(
        label: "my-vibe-island.bridge-server.connections",
        attributes: .concurrent
    )
    private let clientQueue = DispatchQueue(label: "my-vibe-island.bridge-server.clients", attributes: .concurrent)
    // Disconnect monitors may live for the full duration of a blocking hook.
    // Keep their polling work off the queue that must dispatch request handlers.
    private let disconnectMonitorQueue = DispatchQueue(
        label: "my-vibe-island.bridge-server.disconnect-monitors",
        attributes: .concurrent
    )
    private let queueKey = DispatchSpecificKey<Void>()
    private let lock = NSLock()
    private var listenerFD: Int32 = -1
    private var activeClientFDs: Set<Int32> = []
    private var isRunning = false

    public init(
        socketPath: String,
        handler: BridgeRequestHandler,
        codec: BridgeCodec = BridgeCodec(),
        frameByteLimit: Int = 1_048_576,
        maxConcurrentClients: Int = 64
    ) {
        self.socketPath = socketPath
        self.handler = handler
        self.codec = codec
        self.frameByteLimit = min(max(frameByteLimit, 1), Self.hardFrameByteLimit)
        self.maxConcurrentClients = min(max(maxConcurrentClients, 1), Self.hardConcurrentClientLimit)
        queue.setSpecific(key: queueKey, value: ())
    }

    var activeClientCount: Int {
        lock.withLock { activeClientFDs.count }
    }

    public func start() throws {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            throw BridgeSocketError.alreadyRunning
        }
        isRunning = true
        lock.unlock()

        do {
            try startServer()
        } catch {
            lock.lock()
            listenerFD = -1
            isRunning = false
            lock.unlock()
            throw error
        }
    }

    private func startServer() throws {
        let parentPath = URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
        try FileManager.default.createDirectory(
            atPath: parentPath,
            withIntermediateDirectories: true
        )
        var address = try SocketAddress.unix(path: socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BridgeSocketError.socketCreationFailed(errno: errno)
        }
        SocketIO.preventSIGPIPE(on: fd)

        unlink(socketPath)

        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            let bindErrno = errno
            close(fd)
            throw BridgeSocketError.bindFailed(errno: bindErrno)
        }

        guard listen(fd, SOMAXCONN) == 0 else {
            let listenErrno = errno
            close(fd)
            unlink(socketPath)
            throw BridgeSocketError.listenFailed(errno: listenErrno)
        }

        lock.lock()
        listenerFD = fd
        lock.unlock()

        queue.async { [weak self] in
            self?.acceptLoop(listenerFD: fd)
        }
    }

    public func stop() {
        handler.shutdown()
        lock.lock()
        let fd = listenerFD
        let clientFDs = activeClientFDs
        listenerFD = -1
        isRunning = false
        lock.unlock()

        if fd >= 0 {
            shutdown(fd, SHUT_RDWR)
            close(fd)
        }
        for clientFD in clientFDs {
            shutdown(clientFD, SHUT_RDWR)
        }
        unlink(socketPath)

        if DispatchQueue.getSpecific(key: queueKey) == nil {
            queue.sync {}
        }

        lock.lock()
        activeClientFDs.removeAll()
        lock.unlock()
    }

    private func acceptLoop(listenerFD fd: Int32) {
        while running(listenerFD: fd) {
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else {
                if running(listenerFD: fd) {
                    continue
                }
                break
            }
            SocketIO.preventSIGPIPE(on: clientFD)
            SocketIO.setReadTimeout(on: clientFD, seconds: 0, microseconds: 100_000)
            guard trackActiveClientIfCapacity(clientFD) else {
                shutdown(clientFD, SHUT_RDWR)
                close(clientFD)
                continue
            }

            connectionQueue.async { [weak self] in
                guard let self else {
                    close(clientFD)
                    return
                }
                self.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ clientFD: Int32) {
        do {
            let requestLine = try SocketIO.readLine(
                from: clientFD,
                maxBytes: frameByteLimit,
                requireNewline: true
            )
            let envelope = try codec.decodeRequestLine(requestLine)
            let monitor = DisconnectMonitor()
            disconnectMonitorQueue.async { [handler] in
                while monitor.isActive {
                    var byte: UInt8 = 0
                    let result = recv(clientFD, &byte, 1, MSG_PEEK | MSG_DONTWAIT)
                    if result == 0 {
                        if handler.clientDisconnected(envelope) {
                            return
                        }
                    }
                    if result < 0, errno != EAGAIN, errno != EWOULDBLOCK {
                        if handler.clientDisconnected(envelope) {
                            return
                        }
                    }
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
            clientQueue.async { [weak self] in
                guard let self else { return }
                handler.handleAsync(envelope) { response in
                    defer {
                        monitor.stop()
                        if self.untrackActiveClient(clientFD) {
                            close(clientFD)
                        }
                    }

                    guard response.transportDisposition == .reply else {
                        return
                    }
                    let responseLine = envelope.clientRole == "original-bridge"
                        ? try? self.codec.encodeOriginalBridgeResponseLine(response)
                        : try? self.codec.encodeResponseLine(response)
                    if let responseLine {
                        try? SocketIO.writeAll(responseLine, to: clientFD)
                    }
                }
            }
        } catch {
            let response = BridgeResponse.failure(message: "bridge request failed")
            try? SocketIO.writeAll(codec.encodeResponseLine(response), to: clientFD)
            if untrackActiveClient(clientFD) {
                close(clientFD)
            }
        }
    }

    private func running(listenerFD fd: Int32) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        return isRunning && listenerFD == fd
    }

    private func trackActiveClientIfCapacity(_ clientFD: Int32) -> Bool {
        lock.lock()
        guard activeClientFDs.count < maxConcurrentClients else {
            lock.unlock()
            return false
        }
        activeClientFDs.insert(clientFD)
        lock.unlock()
        return true
    }

    private func untrackActiveClient(_ clientFD: Int32) -> Bool {
        lock.lock()
        let removed = activeClientFDs.remove(clientFD) != nil
        lock.unlock()
        return removed
    }
}

private extension Dictionary where Key == String, Value == BridgeJSONValue {
    func stringValue(for key: String) -> String? {
        guard case let .string(value) = self[key], !value.isEmpty else {
            return nil
        }
        return value
    }
}

private final class DisconnectMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true

    var isActive: Bool {
        lock.withLock { active }
    }

    func stop() {
        lock.withLock { active = false }
    }
}
