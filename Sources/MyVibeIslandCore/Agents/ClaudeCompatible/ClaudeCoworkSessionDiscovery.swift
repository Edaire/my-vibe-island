import Foundation

public struct ClaudeCoworkSessionMetadata: Equatable, Sendable {
    public let title: String
    public let cwd: String?
    public let model: String?
    public let cliSessionId: String?
    public let isArchived: Bool
    public let lastActivityAt: Date?

    public init(
        title: String,
        cwd: String? = nil,
        model: String? = nil,
        cliSessionId: String? = nil,
        isArchived: Bool = false,
        lastActivityAt: Date? = nil
    ) {
        self.title = title
        self.cwd = cwd
        self.model = model
        self.cliSessionId = cliSessionId
        self.isArchived = isArchived
        self.lastActivityAt = lastActivityAt
    }

    fileprivate init(data: Data) throws {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawTitle = object["title"] as? String
        else {
            throw ClaudeCoworkSessionMetadataError.invalidObject
        }

        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw ClaudeCoworkSessionMetadataError.emptyTitle
        }

        self.init(
            title: title,
            cwd: Self.nonEmptyString(object["cwd"]),
            model: Self.nonEmptyString(object["model"]),
            cliSessionId: Self.nonEmptyString(object["cliSessionId"]),
            isArchived: object["isArchived"] as? Bool ?? false,
            lastActivityAt: Self.date(from: object["lastActivityAt"])
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func date(from value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let seconds = number.doubleValue / 1_000
            return Date(timeIntervalSince1970: seconds)
        }
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: trimmed) { return date }
        iso8601.formatOptions = [.withInternetDateTime]
        return iso8601.date(from: trimmed)
    }
}

public enum ClaudeCoworkSessionMetadataError: Error, Equatable {
    case invalidObject
    case emptyTitle
}

public struct ClaudeCoworkSessionFile: Equatable, Sendable {
    public let sessionId: String
    public let metadataURL: URL
    public let auditLogURL: URL
    public let metadata: ClaudeCoworkSessionMetadata
    public let auditLogModificationDate: Date?

    public init(
        sessionId: String,
        metadataURL: URL,
        auditLogURL: URL,
        metadata: ClaudeCoworkSessionMetadata,
        auditLogModificationDate: Date? = nil
    ) {
        self.sessionId = sessionId
        self.metadataURL = metadataURL
        self.auditLogURL = auditLogURL
        self.metadata = metadata
        self.auditLogModificationDate = auditLogModificationDate
    }
}

public struct ClaudeCoworkSessionDiscovery: @unchecked Sendable {
    public static let defaultRelativeRoot = "Claude/local-agent-mode-sessions"
    public static let maximumDiscoveredFiles = 2_000

    public let rootURL: URL
    public let maximumFiles: Int
    private let fileManager: FileManager

    public init(
        rootURL: URL? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationSupportDirectory: URL? = nil,
        maximumFiles: Int = Self.maximumDiscoveredFiles,
        fileManager: FileManager = .default
    ) {
        let applicationSupport = applicationSupportDirectory
            ?? homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
        self.rootURL = rootURL
            ?? applicationSupport.appendingPathComponent(Self.defaultRelativeRoot, isDirectory: true)
        self.maximumFiles = max(0, maximumFiles)
        self.fileManager = fileManager
    }

    public func discover() -> [ClaudeCoworkSessionFile] {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return []
        }

        var discovered: [ClaudeCoworkSessionFile] = []
        var visitedFiles = 0
        while visitedFiles < maximumFiles, let url = enumerator.nextObject() as? URL {
            guard isRegularFile(url) else { continue }
            visitedFiles += 1
            guard url.lastPathComponent.hasPrefix("_local"), url.pathExtension == "json" else {
                continue
            }
            guard
                let data = try? Data(contentsOf: url),
                let metadata = try? ClaudeCoworkSessionMetadata(data: data)
            else {
                continue
            }

            let sessionId = url.deletingPathExtension().lastPathComponent
                .dropFirst("_local".count)
            guard !sessionId.isEmpty else { continue }

            let auditLogURL = url
                .deletingPathExtension()
                .appendingPathComponent("audit.log", isDirectory: false)
            let auditDate = (try? fileManager.attributesOfItem(atPath: auditLogURL.path))?[.modificationDate] as? Date
            discovered.append(
                ClaudeCoworkSessionFile(
                    sessionId: String(sessionId),
                    metadataURL: url,
                    auditLogURL: auditLogURL,
                    metadata: metadata,
                    auditLogModificationDate: auditDate
                )
            )
        }

        return discovered.sorted {
            let lhsDate = $0.auditLogModificationDate ?? $0.metadata.lastActivityAt ?? .distantPast
            let rhsDate = $1.auditLogModificationDate ?? $1.metadata.lastActivityAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return $0.sessionId < $1.sessionId
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]) else { return false }
        return values.isRegularFile == true
    }
}

public struct ClaudeCoworkAuditTailReader: Sendable {
    public init() {}

    public func read(from url: URL, maximumBytes: UInt64) throws -> String {
        guard maximumBytes > 0 else { return "" }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let endOffset = try handle.seekToEnd()
        let startOffset = endOffset > maximumBytes ? endOffset - maximumBytes : 0
        try handle.seek(toOffset: startOffset)
        guard let data = try handle.readToEnd(), !data.isEmpty else { return "" }

        let text = String(decoding: data, as: UTF8.self)
        guard startOffset > 0 else { return text }
        guard let newline = text.firstIndex(of: "\n") else { return "" }
        return String(text[text.index(after: newline)...])
    }
}
