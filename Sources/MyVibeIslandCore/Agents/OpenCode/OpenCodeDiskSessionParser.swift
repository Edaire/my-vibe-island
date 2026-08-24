import Foundation

public enum OpenCodeDiskSessionParser {
    public static func parseSnapshot(from data: Data) throws -> OpenCodeDiskSessionSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OpenCodeDiskSessionSnapshot.self, from: data)
    }
}

public struct OpenCodeDiskSessionSnapshot: Decodable, Equatable, Sendable {
    public let session: OpenCodeDiskSessionInfo
    public let messages: [OpenCodeMessage]

    public func agentEvents() -> [AgentEvent] {
        var events: [AgentEvent] = [
            .sessionStarted(source: "opencode", sessionId: session.directory, cwd: session.directory)
        ]

        if let parentID = session.parentID, !parentID.isEmpty {
            events.append(
                .teamGroupingUpdated(
                    source: "opencode",
                    sessionId: session.directory,
                    grouping: TeamGrouping(
                        rootSessionId: parentID,
                        childToParent: [session.directory: parentID]
                    )
                )
            )
        }

        events.append(contentsOf: messages.map { message in
            .messageReceived(
                source: "opencode",
                sessionId: message.sessionID,
                message: message.redactedSummary
            )
        })

        return events
    }
}

public struct OpenCodeDiskSessionInfo: Decodable, Equatable, Sendable {
    public let directory: String
    public let title: String?
    public let archivedAt: Date?
    public let parentID: String?
    public let hasParentIDColumn: Bool?
}

public struct OpenCodeMessage: Decodable, Equatable, Sendable {
    public let id: String
    public let sessionID: String
    public let role: String?
    public let modelID: String?
    public let cost: Double?
    public let tokens: OpenCodeTokens?
    public let time: OpenCodeMessageTime?
    public let error: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionID
        case role
        case modelID
        case cost
        case tokens
        case time
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        modelID = try container.decodeIfPresent(String.self, forKey: .modelID)
        cost = try container.decodeFlexibleDoubleIfPresent(forKey: .cost)
        tokens = try container.decodeIfPresent(OpenCodeTokens.self, forKey: .tokens)
        time = try container.decodeIfPresent(OpenCodeMessageTime.self, forKey: .time)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    fileprivate var redactedSummary: String {
        var parts: [String] = []
        if let role, !role.isEmpty {
            parts.append(role)
        }
        if let modelID, !modelID.isEmpty {
            parts.append(modelID)
        }
        if let error, !error.isEmpty {
            parts.append("error")
        }
        return parts.isEmpty ? id : parts.joined(separator: " ")
    }
}

public struct OpenCodeMessageTime: Decodable, Equatable, Sendable {
    public let created: Date?
    public let completed: Date?
}

public struct OpenCodeTokens: Decodable, Equatable, Sendable {
    public let input: Int?
    public let output: Int?
    public let reasoning: Int?
    public let cache: OpenCodeCacheTokens?

    private enum CodingKeys: String, CodingKey {
        case input
        case output
        case reasoning
        case cache
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        input = try container.decodeFlexibleIntIfPresent(forKey: .input)
        output = try container.decodeFlexibleIntIfPresent(forKey: .output)
        reasoning = try container.decodeFlexibleIntIfPresent(forKey: .reasoning)
        cache = try container.decodeIfPresent(OpenCodeCacheTokens.self, forKey: .cache)
    }
}

public struct OpenCodeCacheTokens: Decodable, Equatable, Sendable {
    public let read: Int?
    public let write: Int?

    private enum CodingKeys: String, CodingKey {
        case read
        case write
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        read = try container.decodeFlexibleIntIfPresent(forKey: .read)
        write = try container.decodeFlexibleIntIfPresent(forKey: .write)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return Double(value)
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return Int(value)
        }
        return nil
    }
}
