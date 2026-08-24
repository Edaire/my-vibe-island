import Foundation

public enum OpenCodeSessionReadError: Error, Equatable, Sendable {
    case fileTooLarge
}

public protocol OpenCodeSessionDataReading: Sendable {
    func read(_ url: URL, maximumBytes: Int) throws -> Data
}

public struct FoundationOpenCodeSessionDataReader: OpenCodeSessionDataReading, Sendable {
    public init() {}

    public func read(_ url: URL, maximumBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: max(1, maximumBytes) + 1) ?? Data()
        guard data.count <= maximumBytes else { throw OpenCodeSessionReadError.fileTooLarge }
        return data
    }
}

enum OpenCodeScanTruncationReason: Equatable, Sendable {
    case depthLimit
    case visitedEntriesLimit
    case fileCountLimit
    case directoryReadFailed
}

struct OpenCodeBoundedJSONFileScan: Equatable, Sendable {
    let files: [URL]
    let isComplete: Bool
    let truncationReason: OpenCodeScanTruncationReason?
    let visitedEntries: Int
}

struct OpenCodeBoundedJSONFileScanner {
    let fileManager: FileManager
    let maximumFileCount: Int
    let maximumDepth: Int
    let maximumVisitedEntries: Int

    func scan(rootURL: URL) -> OpenCodeBoundedJSONFileScan {
        guard maximumFileCount > 0 else {
            return OpenCodeBoundedJSONFileScan(
                files: [], isComplete: false, truncationReason: .fileCountLimit, visitedEntries: 0
            )
        }
        guard maximumVisitedEntries > 0 else {
            return OpenCodeBoundedJSONFileScan(
                files: [], isComplete: false, truncationReason: .visitedEntriesLimit, visitedEntries: 0
            )
        }
        var directories: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var directoryIndex = 0
        var visitedEntries = 0
        var files: [URL] = []
        var truncationReason: OpenCodeScanTruncationReason?

        while directoryIndex < directories.count {
            let directory = directories[directoryIndex]
            directoryIndex += 1
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory.url,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ).sorted(by: { $0.standardizedFileURL.path < $1.standardizedFileURL.path }) else {
                if directoryIndex == 1 {
                    return OpenCodeBoundedJSONFileScan(
                        files: files,
                        isComplete: false,
                        truncationReason: .directoryReadFailed,
                        visitedEntries: visitedEntries
                    )
                }
                truncationReason = truncationReason ?? .directoryReadFailed
                continue
            }

            for entry in entries {
                guard visitedEntries < maximumVisitedEntries, files.count < maximumFileCount else {
                    return OpenCodeBoundedJSONFileScan(
                        files: files,
                        isComplete: false,
                        truncationReason: files.count == maximumFileCount ? .fileCountLimit : .visitedEntriesLimit,
                        visitedEntries: visitedEntries
                    )
                }
                visitedEntries += 1
                guard let values = try? entry.resourceValues(
                    forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
                ), values.isSymbolicLink != true else {
                    if visitedEntries == maximumVisitedEntries {
                        return OpenCodeBoundedJSONFileScan(
                            files: files,
                            isComplete: false,
                            truncationReason: .visitedEntriesLimit,
                            visitedEntries: visitedEntries
                        )
                    }
                    continue
                }

                if values.isDirectory == true {
                    guard directory.depth < maximumDepth else {
                        truncationReason = truncationReason ?? .depthLimit
                        continue
                    }
                    directories.append((entry, directory.depth + 1))
                } else if values.isRegularFile == true, entry.pathExtension == "json" {
                    files.append(entry)
                }

                if visitedEntries == maximumVisitedEntries || files.count == maximumFileCount {
                    return OpenCodeBoundedJSONFileScan(
                        files: files,
                        isComplete: false,
                        truncationReason: files.count == maximumFileCount ? .fileCountLimit : .visitedEntriesLimit,
                        visitedEntries: visitedEntries
                    )
                }
            }
        }
        return OpenCodeBoundedJSONFileScan(
            files: files,
            isComplete: truncationReason == nil,
            truncationReason: truncationReason,
            visitedEntries: visitedEntries
        )
    }
}

public struct OpenCodeDiskSessionScanResult: Equatable, Sendable {
    public let fileURL: URL
    public let snapshot: OpenCodeDiskSessionSnapshot?
    public let errorDescription: String?

    public static func success(fileURL: URL, snapshot: OpenCodeDiskSessionSnapshot) -> Self {
        Self(fileURL: fileURL, snapshot: snapshot, errorDescription: nil)
    }

    public static func failure(fileURL: URL, error: Error) -> Self {
        Self(fileURL: fileURL, snapshot: nil, errorDescription: String(describing: error))
    }
}

public struct OpenCodeDiskSessionWatcher {
    public static let defaultMaximumFileCount = 256
    public static let defaultMaximumVisitedEntries = 4_096
    public static let defaultMaximumSnapshotBytes = 1_048_576
    public let rootURL: URL
    private let fileManager: FileManager
    private let dataReader: OpenCodeSessionDataReading
    private let maximumFileCount: Int
    private let maximumVisitedEntries: Int
    private let maximumSnapshotBytes: Int

    public init(
        rootURL: URL,
        fileManager: FileManager = .default,
        dataReader: OpenCodeSessionDataReading = FoundationOpenCodeSessionDataReader(),
        maximumFileCount: Int = Self.defaultMaximumFileCount,
        maximumVisitedEntries: Int = Self.defaultMaximumVisitedEntries,
        maximumSnapshotBytes: Int = Self.defaultMaximumSnapshotBytes
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.dataReader = dataReader
        self.maximumFileCount = max(0, maximumFileCount)
        self.maximumVisitedEntries = max(0, maximumVisitedEntries)
        self.maximumSnapshotBytes = max(1, maximumSnapshotBytes)
    }

    public func scan() -> [OpenCodeDiskSessionScanResult] {
        OpenCodeBoundedJSONFileScanner(
            fileManager: fileManager,
            maximumFileCount: maximumFileCount,
            maximumDepth: 0,
            maximumVisitedEntries: maximumVisitedEntries
        ).scan(rootURL: rootURL).files
            .map { fileURL in
                do {
                    let data = try dataReader.read(fileURL, maximumBytes: maximumSnapshotBytes)
                    let snapshot = try OpenCodeDiskSessionParser.parseSnapshot(from: data)
                    return .success(fileURL: fileURL, snapshot: snapshot)
                } catch {
                    return .failure(fileURL: fileURL, error: error)
                }
            }
    }

    public func agentEvents() -> [AgentEvent] {
        scan().flatMap { result in
            result.snapshot?.agentEvents() ?? []
        }
    }
}
