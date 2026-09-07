import Foundation

public struct ClaudeDiscoveredTranscript: Equatable, Sendable {
    public let fileURL: URL
    public let sessionId: String
    public let cwd: String
    public let firstUserMessage: String?
    public let lastUserMessage: String?
    public let lastAssistantMessage: String?

    public init(
        fileURL: URL,
        sessionId: String,
        cwd: String,
        firstUserMessage: String? = nil,
        lastUserMessage: String? = nil,
        lastAssistantMessage: String? = nil
    ) {
        self.fileURL = fileURL
        self.sessionId = sessionId
        self.cwd = cwd
        self.firstUserMessage = firstUserMessage
        self.lastUserMessage = lastUserMessage
        self.lastAssistantMessage = lastAssistantMessage
    }

    public func agentEvents() -> [AgentEvent] {
        var events: [AgentEvent] = [
            .sessionStarted(source: "claude", sessionId: sessionId, cwd: cwd),
        ]
        if let summary = lastAssistantMessage ?? lastUserMessage {
            events.append(.sessionActivityUpdated(
                source: "claude",
                sessionId: sessionId,
                activity: SessionActivityUpdate(
                    status: .active,
                    summary: summary,
                    lastAssistantMessage: lastAssistantMessage,
                    firstUserMessage: firstUserMessage,
                    lastUserMessage: lastUserMessage,
                    cwd: cwd
                )
            ))
        }
        return events
    }

    public var description: String { "claude transcript \(sessionId) at \(cwd)" }
}

public final class ClaudeTranscriptDiscovery: @unchecked Sendable {
    public static let defaultRelativeRoot = ".claude/projects"
    public static let maximumTranscriptBytes = 262_144
    public let rootURL: URL
    private let fileManager: FileManager
    private let maximumFiles: Int
    private let maximumDepth: Int
    private let maximumFirstLineBytes: Int
    private let queue: DispatchQueue
    private let workLock = NSLock()
    private var workItem: DispatchWorkItem?
    private var generation: UInt64 = 0

    public init(
        rootURL: URL? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        maximumFiles: Int = 256,
        maximumDepth: Int = 4,
        maximumFirstLineBytes: Int = 16_384,
        queue: DispatchQueue = DispatchQueue(label: "my-vibe-island.claude-transcript-discovery")
    ) {
        self.rootURL = rootURL ?? homeDirectory.appendingPathComponent(Self.defaultRelativeRoot, isDirectory: true)
        self.fileManager = fileManager
        self.maximumFiles = max(0, maximumFiles)
        self.maximumDepth = max(0, maximumDepth)
        self.maximumFirstLineBytes = max(1, maximumFirstLineBytes)
        self.queue = queue
    }

    public func start(eventHandler: @escaping @Sendable (AgentEvent) -> Void) {
        workLock.lock()
        workItem?.cancel()
        generation &+= 1
        let token = generation
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isCurrent(token) else { return }
            for event in self.agentEvents() {
                guard self.isCurrent(token) else { return }
                eventHandler(event)
            }
        }
        workItem = item
        workLock.unlock()
        queue.async(execute: item)
    }

    public func stop() {
        workLock.lock()
        generation &+= 1
        workItem?.cancel()
        workItem = nil
        workLock.unlock()
    }

    private func isCurrent(_ token: UInt64) -> Bool {
        workLock.lock()
        defer { workLock.unlock() }
        return generation == token
    }

    public func discover() -> [ClaudeDiscoveredTranscript] {
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var candidates: [(url: URL, object: [String: Any])] = []
        let rootComponentCount = rootURL.standardizedFileURL.pathComponents.count
        for case let url as URL in enumerator {
            let relativeComponentCount = url.standardizedFileURL.pathComponents.count - rootComponentCount
            let fileDepth = max(0, relativeComponentCount - 1)
            if fileDepth > maximumDepth {
                enumerator.skipDescendants()
                continue
            }
            guard url.pathExtension == "jsonl",
                  let line = firstLine(at: url),
                  let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            else { continue }
            candidates.append((url, object))
        }

        let selected = candidates.sorted {
            modificationDate(of: $0.url) > modificationDate(of: $1.url)
        }.prefix(maximumFiles)
        var discovered: [ClaudeDiscoveredTranscript] = []
        for candidate in selected {
            let url = candidate.url
            let object = candidate.object
            let sessionId = (object["sessionId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? url.deletingPathExtension().lastPathComponent
            let cwd = (object["cwd"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? rootURL.path
            let messages = conversationMessages(at: url)
            discovered.append(ClaudeDiscoveredTranscript(
                fileURL: url,
                sessionId: sessionId,
                cwd: cwd,
                firstUserMessage: messages.firstUser,
                lastUserMessage: messages.lastUser,
                lastAssistantMessage: messages.lastAssistant
            ))
        }
        return discovered
    }

    public func agentEvents() -> [AgentEvent] { discover().flatMap { $0.agentEvents() } }

    private func firstLine(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: maximumFirstLineBytes + 1) else { return nil }
        defer { try? handle.close() }
        if let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
            let line = data.prefix(upTo: newline)
            guard line.count <= maximumFirstLineBytes else { return nil }
            return String(decoding: line, as: UTF8.self)
        }
        guard data.count <= maximumFirstLineBytes else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func conversationMessages(at url: URL) -> (firstUser: String?, lastUser: String?, lastAssistant: String?) {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let data = try? handle.read(upToCount: Self.maximumTranscriptBytes) else {
            return (nil, nil, nil)
        }
        defer { try? handle.close() }

        var firstUser: String?
        var lastUser: String?
        var lastAssistant: String?
        for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let type = object["type"] as? String,
                  type == "user" || type == "assistant",
                  let text = messageText(from: object["message"] ?? object["content"]),
                  !text.isEmpty else { continue }
            if type == "user" {
                firstUser = firstUser ?? text
                lastUser = text
            } else {
                lastAssistant = text
            }
        }
        return (firstUser, lastUser, lastAssistant)
    }

    private func messageText(from value: Any?) -> String? {
        if let text = value as? String { return text }
        if let message = value as? [String: Any] {
            return messageText(from: message["content"] ?? message["text"])
        }
        if let blocks = value as? [[String: Any]] {
            let text = blocks.compactMap { block -> String? in
                if let value = block["text"] as? String { return value }
                return block["content"] as? String
            }.joined(separator: "\n")
            return text.isEmpty ? nil : text
        }
        return nil
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
