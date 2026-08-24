import Darwin
import Foundation

public enum BridgeSocketError: Error, Equatable {
    case pathTooLong(String)
    case alreadyRunning
    case socketCreationFailed(errno: Int32)
    case connectFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
    case acceptFailed(errno: Int32)
    case readFailed(errno: Int32)
    case writeFailed(errno: Int32)
    case frameTooLarge(limit: Int)
    case incompleteFrame
    case emptyResponse
}

public struct BridgeClient: Sendable {
    private let socketPath: String
    private let codec: BridgeCodec

    public init(socketPath: String, codec: BridgeCodec = BridgeCodec()) {
        self.socketPath = socketPath
        self.codec = codec
    }

    public func send(_ envelope: BridgeEnvelope) throws -> BridgeResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BridgeSocketError.socketCreationFailed(errno: errno)
        }
        defer {
            close(fd)
        }
        SocketIO.preventSIGPIPE(on: fd)

        var address = try SocketAddress.unix(path: socketPath)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            throw BridgeSocketError.connectFailed(errno: errno)
        }

        try SocketIO.writeAll(codec.encodeEnvelopeLine(envelope), to: fd)
        let line = try SocketIO.readLine(from: fd)
        guard !line.isEmpty else {
            throw BridgeSocketError.emptyResponse
        }

        return try codec.decodeResponseLine(line)
    }

    /// Sends an event whose hook contract does not consume a bridge response.
    ///
    /// Lifecycle and tool-observation hooks must not inherit the latency of the
    /// bridge's reducer, persistence, or UI publication work. The peer may
    /// close immediately or never write a response; both are valid here.
    public func sendFireAndForget(_ envelope: BridgeEnvelope) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw BridgeSocketError.socketCreationFailed(errno: errno)
        }
        defer {
            close(fd)
        }
        SocketIO.preventSIGPIPE(on: fd)

        var address = try SocketAddress.unix(path: socketPath)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            throw BridgeSocketError.connectFailed(errno: errno)
        }

        try SocketIO.writeAll(codec.encodeEnvelopeLine(envelope), to: fd)
    }
}

enum SocketAddress {
    static func unix(path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let maxLength = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < maxLength else {
            throw BridgeSocketError.pathTooLong(path)
        }

        _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: maxLength) { buffer in
                path.withCString { source in
                    strncpy(buffer, source, maxLength)
                }
            }
        }

        return address
    }
}

enum SocketIO {
    static func preventSIGPIPE(on fd: Int32) {
        var value: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout.size(ofValue: value)))
    }

    static func setReadTimeout(on fd: Int32, seconds: Int, microseconds: Int) {
        var timeout = timeval(tv_sec: seconds, tv_usec: Int32(microseconds))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
    }

    static func writeAll(_ string: String, to fd: Int32) throws {
        let bytes = Array(string.utf8)
        try bytes.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            var sent = 0
            while sent < rawBuffer.count {
                let written = write(fd, baseAddress.advanced(by: sent), rawBuffer.count - sent)
                guard written > 0 else {
                    throw BridgeSocketError.writeFailed(errno: errno)
                }
                sent += written
            }
        }
    }

    static func readLine(
        from fd: Int32,
        maxBytes: Int = 1_048_576,
        requireNewline: Bool = false
    ) throws -> String {
        var bytes: [UInt8] = []
        var byte: UInt8 = 0

        while true {
            let count = read(fd, &byte, 1)
            if count == 0 {
                if requireNewline, bytes.last != UInt8(ascii: "\n") {
                    throw BridgeSocketError.incompleteFrame
                }
                break
            }
            guard count > 0 else {
                if requireNewline, errno == EAGAIN || errno == EWOULDBLOCK {
                    throw BridgeSocketError.incompleteFrame
                }
                throw BridgeSocketError.readFailed(errno: errno)
            }

            bytes.append(byte)
            guard bytes.count <= maxBytes else {
                throw BridgeSocketError.frameTooLarge(limit: maxBytes)
            }
            if byte == UInt8(ascii: "\n") {
                break
            }
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}
