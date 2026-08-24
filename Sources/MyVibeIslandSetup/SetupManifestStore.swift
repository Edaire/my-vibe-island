import Foundation

public enum SetupManifestStoreError: Error, Equatable, LocalizedError {
    case writeFailed(String)
    case removalFailed(String)

    public var errorDescription: String? {
        switch self {
        case .writeFailed(let path): return "failed to write setup manifest at \(path)"
        case .removalFailed(let path): return "failed to remove setup manifest at \(path)"
        }
    }
}

public struct SetupManifestStore {
    public static let relativePath = ".config/my-vibe-island/setup-manifest.json"
    private let fileURL: URL
    private let pathPolicy: SetupHomePathPolicy

    public init(homeDirectory: URL) {
        fileURL = homeDirectory.appendingPathComponent(Self.relativePath)
        pathPolicy = SetupHomePathPolicy(homeDirectory: homeDirectory)
    }

    public func load(sourceId: String) throws -> SetupManifest? {
        let resolved = try pathPolicy.resolve(fileURL)
        guard FileManager.default.fileExists(atPath: resolved.path) else { return nil }
        let data = try Data(contentsOf: resolved)
        let manifests = try JSONDecoder().decode([SetupManifest].self, from: data)
        return manifests.first { $0.sourceId == sourceId }
    }

    public func all() throws -> [SetupManifest] {
        try all(at: pathPolicy.resolve(fileURL))
    }

    public func save(_ manifest: SetupManifest) throws {
        do {
            let resolved = try pathPolicy.resolve(fileURL)
            var manifests = try all(at: resolved).filter { $0.sourceId != manifest.sourceId }
            manifests.append(manifest)
            let data = try JSONEncoder().encode(manifests.sorted { $0.sourceId < $1.sourceId })
            try FileManager.default.createDirectory(at: resolved.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: resolved, options: .atomic)
        } catch let error as SetupPathError {
            throw error
        } catch let error as SetupManifestStoreError {
            throw error
        } catch {
            throw SetupManifestStoreError.writeFailed(fileURL.path)
        }
    }

    public func remove(sourceId: String) throws {
        do {
            let resolved = try pathPolicy.resolve(fileURL)
            let manifests = try all(at: resolved).filter { $0.sourceId != sourceId }
            guard !manifests.isEmpty else {
                if FileManager.default.fileExists(atPath: resolved.path) {
                    try FileManager.default.removeItem(at: resolved)
                }
                return
            }
            try JSONEncoder().encode(manifests).write(to: resolved, options: .atomic)
        } catch let error as SetupPathError {
            throw error
        } catch let error as SetupManifestStoreError {
            throw error
        } catch {
            throw SetupManifestStoreError.removalFailed(fileURL.path)
        }
    }

    private func all(at url: URL) throws -> [SetupManifest] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([SetupManifest].self, from: Data(contentsOf: url))
    }
}
