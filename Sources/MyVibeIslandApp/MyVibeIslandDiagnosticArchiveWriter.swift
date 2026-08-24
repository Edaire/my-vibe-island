import Foundation
import MyVibeIslandCore

public enum MyVibeIslandDiagnosticArchiveError: Error, Equatable {
    case failedClosed
    case invalidEntryPath
    case archiveFailed(Int32)
}

public struct MyVibeIslandDiagnosticArchiveWriter {
    public init() {}

    @discardableResult
    public func write(
        plan: DiagnosticExportWritePlan,
        to archiveURL: URL
    ) throws -> URL {
        guard plan.status == .ready else {
            throw MyVibeIslandDiagnosticArchiveError.failedClosed
        }

        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MyVibeIslandDiagnostics-" + UUID().uuidString, isDirectory: true)
        let bundleURL = temporaryRoot
            .appendingPathComponent("Vibe-Island-Diagnostics", isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for entry in plan.entries {
            guard isSafeRelativePath(entry.path) else {
                throw MyVibeIslandDiagnosticArchiveError.invalidEntryPath
            }
            let entryURL = bundleURL.appendingPathComponent(entry.path)
            try fileManager.createDirectory(
                at: entryURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(entry.fields).write(to: entryURL, options: .atomic)
        }

        try fileManager.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.removeItem(at: archiveURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            bundleURL.path, archiveURL.path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            try? fileManager.removeItem(at: archiveURL)
            throw MyVibeIslandDiagnosticArchiveError.archiveFailed(process.terminationStatus)
        }
        return archiveURL
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
        !path.isEmpty
            && !path.hasPrefix("/")
            && !path.split(separator: "/").contains("..")
    }
}
