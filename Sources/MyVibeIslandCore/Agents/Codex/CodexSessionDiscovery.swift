import Foundation

public struct CodexDiscoveredRolloutFile: Equatable, Sendable {
    public let url: URL
    public let size: UInt64
    public let inode: UInt64?
    public let modificationDate: Date?

    public init(url: URL, size: UInt64, inode: UInt64?, modificationDate: Date? = nil) {
        self.url = url
        self.size = size
        self.inode = inode
        self.modificationDate = modificationDate
    }
}

public struct CodexSessionDiscovery: @unchecked Sendable {
    public let roots: [URL]
    public let maximumFiles: Int?
    private let fileManager: FileManager

    public init(
        roots: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/sessions", isDirectory: true)
        ],
        maximumFiles: Int? = nil,
        fileManager: FileManager = .default
    ) {
        self.roots = roots
        self.maximumFiles = maximumFiles.map { max(0, $0) }
        self.fileManager = fileManager
    }

    public func discover() -> [CodexDiscoveredRolloutFile] {
        let sorted = roots.flatMap(discover(root:)).sorted {
            let lhsDate = $0.modificationDate ?? .distantPast
            let rhsDate = $1.modificationDate ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return $0.url.path < $1.url.path
        }
        guard let maximumFiles else { return sorted }
        return Array(sorted.prefix(maximumFiles))
    }

    public func file(at url: URL) -> CodexDiscoveredRolloutFile? {
        guard
            url.lastPathComponent.hasPrefix("rollout-"),
            url.pathExtension == "jsonl",
            fileManager.fileExists(atPath: url.path),
            let attributes = try? fileManager.attributesOfItem(atPath: url.path),
            (attributes[.type] as? FileAttributeType) == .typeRegular
        else {
            return nil
        }

        return CodexDiscoveredRolloutFile(
            url: url.standardizedFileURL.resolvingSymlinksInPath(),
            size: (attributes[.size] as? NSNumber)?.uint64Value ?? 0,
            inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }

    private func discover(root: URL) -> [CodexDiscoveredRolloutFile] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [CodexDiscoveredRolloutFile] = []
        for case let url as URL in enumerator {
            if let file = file(at: url) {
                files.append(file)
            }
        }
        return files
    }
}
