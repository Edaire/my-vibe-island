import Foundation

public enum CustomSoundLibraryStoreError: Error, Equatable, Sendable {
    case invalidSourceFile
    case unsupportedFormat
    case invalidStoredFileName
    case invalidManifest
}

public final class CustomSoundLibraryStore: @unchecked Sendable {
    private static let manifestFileName = "manifest.json"

    private let libraryDirectory: URL
    private let fileManager: FileManager
    private let now: @Sendable () -> Date

    public init(
        libraryDirectory: URL,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.libraryDirectory = libraryDirectory.standardizedFileURL
        self.fileManager = fileManager
        self.now = now
    }

    public func importFile(at sourceURL: URL, displayName: String? = nil) throws -> CustomSoundFile {
        guard sourceURL.isFileURL,
              fileManager.fileExists(atPath: sourceURL.path) else {
            throw CustomSoundLibraryStoreError.invalidSourceFile
        }

        let format = try soundFormat(for: sourceURL)
        try createLibraryDirectory()
        let state = try loadState()

        for file in state.files {
            let existingURL = try fileURL(forStoredFileName: file.storedFileName)
            if fileManager.fileExists(atPath: existingURL.path),
               fileManager.contentsEqual(atPath: sourceURL.path, andPath: existingURL.path) {
                return file
            }
        }

        let id = UUID().uuidString.lowercased()
        let storedFileName = "\(id).\(sourceURL.pathExtension.lowercased())"
        let destinationURL = try fileURL(forStoredFileName: storedFileName)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let sound = CustomSoundFile(
            id: id,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? sourceURL.deletingPathExtension().lastPathComponent.nonEmpty
                ?? "Custom Sound",
            storedFileName: storedFileName,
            sourceMode: .copiedIntoLibrary,
            format: format,
            createdAtUnixSeconds: Int(now().timeIntervalSince1970)
        )
        try save(files: state.files + [sound])
        return sound
    }

    public func loadSnapshot() throws -> CustomSoundStoreSnapshot {
        try createLibraryDirectory()
        let state = try loadState()
        return CustomSoundStoreSnapshot(
            files: state.files,
            hasLoaded: true,
            libraryDirectory: try canonicalLibraryDirectory().path,
            manifest: state.manifest
        )
    }

    public func fileURL(forStoredFileName storedFileName: String) throws -> URL {
        guard isSafeStoredFileName(storedFileName) else {
            throw CustomSoundLibraryStoreError.invalidStoredFileName
        }

        let directory = try canonicalLibraryDirectory()
        let candidate = directory.appendingPathComponent(storedFileName, isDirectory: false)
        let resolvedCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(resolvedCandidate, in: directory) else {
            throw CustomSoundLibraryStoreError.invalidStoredFileName
        }
        return candidate
    }

    private func soundFormat(for url: URL) throws -> CustomSoundFormat {
        switch url.pathExtension.lowercased() {
        case "wav":
            return .wav
        case "aiff", "aif":
            return .aiff
        default:
            throw CustomSoundLibraryStoreError.unsupportedFormat
        }
    }

    private func createLibraryDirectory() throws {
        try fileManager.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
    }

    private func canonicalLibraryDirectory() throws -> URL {
        try createLibraryDirectory()
        return libraryDirectory.resolvingSymlinksInPath().standardizedFileURL
    }

    private func loadState() throws -> PersistedManifest {
        let manifestURL = try manifestURL()
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return PersistedManifest(manifest: CustomSoundLibraryManifest(), files: [])
        }

        guard let state = try? JSONDecoder().decode(PersistedManifest.self, from: Data(contentsOf: manifestURL)),
              state.files.allSatisfy({ isSafeStoredFileName($0.storedFileName) }) else {
            throw CustomSoundLibraryStoreError.invalidManifest
        }
        return state
    }

    private func save(files: [CustomSoundFile]) throws {
        let timestamp = max(Int(now().timeIntervalSince1970), 0)
        let state = PersistedManifest(
            manifest: CustomSoundLibraryManifest(
                soundIds: files.map(\.id),
                lastUpdatedUnixSeconds: timestamp
            ),
            files: files
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: try manifestURL(), options: .atomic)
    }

    private func manifestURL() throws -> URL {
        try fileURL(forStoredFileName: Self.manifestFileName)
    }

    private func isSafeStoredFileName(_ name: String) -> Bool {
        !name.isEmpty &&
            name == URL(fileURLWithPath: name).lastPathComponent &&
            name != "." &&
            name != ".." &&
            !name.contains("/") &&
            !name.contains("\\")
    }

    private func isContained(_ url: URL, in directory: URL) -> Bool {
        let directoryPath = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
        return url.path.hasPrefix(directoryPath)
    }
}

private struct PersistedManifest: Codable {
    let manifest: CustomSoundLibraryManifest
    let files: [CustomSoundFile]
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
