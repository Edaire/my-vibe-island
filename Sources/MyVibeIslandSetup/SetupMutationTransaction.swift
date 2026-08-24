import Foundation

public enum SetupPathError: Error, Equatable, LocalizedError {
    case outsideHome(String)

    public var errorDescription: String? {
        switch self {
        case .outsideHome(let path): return "setup path escapes home: \(path)"
        }
    }
}

struct SetupHomePathPolicy {
    let canonicalHome: URL

    init(homeDirectory: URL) {
        canonicalHome = homeDirectory.standardizedFileURL.resolvingSymlinksInPath()
    }

    func resolve(_ url: URL) throws -> URL {
        var ancestor = url.standardizedFileURL
        var suffix = [String]()
        while !pathEntryExists(ancestor), ancestor.path != "/" {
            suffix.insert(ancestor.lastPathComponent, at: 0)
            ancestor.deleteLastPathComponent()
        }
        var resolved = ancestor.resolvingSymlinksInPath()
        for component in suffix { resolved.appendPathComponent(component) }
        resolved = resolved.standardizedFileURL
        let homePath = canonicalHome.path
        guard resolved.path == homePath || resolved.path.hasPrefix(homePath + "/") else {
            throw SetupPathError.outsideHome(resolved.path)
        }
        return resolved
    }

    private func pathEntryExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) ||
            (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
}

final class SetupMutationTransaction {
    private enum Snapshot {
        case missing
        case file(Data)
        case directory
    }

    private let policy: SetupHomePathPolicy
    private var snapshots: [String: Snapshot] = [:]
    private var snapshotOrder: [URL] = []
    private var createdDirectories: [URL] = []

    init(homeDirectory: URL) {
        policy = SetupHomePathPolicy(homeDirectory: homeDirectory)
    }

    func resolve(_ url: URL) throws -> URL {
        try policy.resolve(url)
    }

    func validate(_ urls: [URL]) throws -> [URL] {
        try urls.map(resolve)
    }

    func prepareExternalMutation(at url: URL) throws {
        let resolved = try resolve(url)
        try capture(resolved)
        trackMissingDirectories(for: resolved)
    }

    func write(_ data: Data, to url: URL) throws {
        let resolved = try resolve(url)
        try capture(resolved)
        trackMissingDirectories(for: resolved)
        try FileManager.default.createDirectory(at: resolved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: resolved, options: .atomic)
    }

    func remove(_ url: URL) throws {
        let resolved = try resolve(url)
        try capture(resolved)
        guard FileManager.default.fileExists(atPath: resolved.path) else { return }
        try FileManager.default.removeItem(at: resolved)
    }

    func rollback() {
        for url in snapshotOrder.reversed() {
            guard let snapshot = snapshots[url.path] else { continue }
            switch snapshot {
            case .missing:
                try? FileManager.default.removeItem(at: url)
            case .file(let data):
                if isDirectory(url) { try? FileManager.default.removeItem(at: url) }
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            case .directory:
                if FileManager.default.fileExists(atPath: url.path), !isDirectory(url) {
                    try? FileManager.default.removeItem(at: url)
                }
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
        for directory in createdDirectories.reversed() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func capture(_ url: URL) throws {
        guard snapshots[url.path] == nil else { return }
        let snapshot: Snapshot
        if isDirectory(url) {
            snapshot = .directory
        } else if FileManager.default.fileExists(atPath: url.path) {
            snapshot = .file(try Data(contentsOf: url))
        } else {
            snapshot = .missing
        }
        snapshots[url.path] = snapshot
        snapshotOrder.append(url)
    }

    private func trackMissingDirectories(for url: URL) {
        var missing = [URL]()
        var directory = url.deletingLastPathComponent()
        while directory.path != policy.canonicalHome.path,
              directory.path.hasPrefix(policy.canonicalHome.path + "/"),
              !FileManager.default.fileExists(atPath: directory.path) {
            missing.append(directory)
            directory.deleteLastPathComponent()
        }
        for directory in missing.reversed() where !createdDirectories.contains(directory) {
            createdDirectories.append(directory)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
