import Foundation

public struct MyVibeIslandBundledBridgeInstallResult: Equatable, Sendable {
    public let sourceURL: URL
    public let destinationURL: URL
    public let changed: Bool

    public init(sourceURL: URL, destinationURL: URL, changed: Bool) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.changed = changed
    }
}

public struct MyVibeIslandBundledBridgeInstaller: Sendable {
    public let sourceURL: URL
    public let destinationURL: URL

    public init(sourceURL: URL, destinationURL: URL) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
    }

    public static func production(
        bundle: Bundle = .main,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> MyVibeIslandBundledBridgeInstaller {
        MyVibeIslandBundledBridgeInstaller(
            sourceURL: bundle.bundleURL
                .appendingPathComponent("Contents/Resources/Hooks/my-vibe-island-bridge"),
            destinationURL: homeDirectory
                .appendingPathComponent(".my-vibe-island/bin/my-vibe-island-bridge")
        )
    }

    public func install(fileManager: FileManager = .default) throws -> MyVibeIslandBundledBridgeInstallResult {
        let sourceData = try Data(contentsOf: sourceURL)
        let destinationExists = fileManager.fileExists(atPath: destinationURL.path)
        let destinationData = destinationExists ? try Data(contentsOf: destinationURL) : nil

        if destinationData == sourceData {
            let changed = try makeExecutable(fileManager: fileManager)
            return MyVibeIslandBundledBridgeInstallResult(
                sourceURL: sourceURL,
                destinationURL: destinationURL,
                changed: changed
            )
        }

        let directory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".my-vibe-island-bridge-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporary) }
        try fileManager.copyItem(at: sourceURL, to: temporary)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)

        if destinationExists {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destinationURL)
        }

        return MyVibeIslandBundledBridgeInstallResult(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            changed: true
        )
    }

    private func makeExecutable(fileManager: FileManager) throws -> Bool {
        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue
        guard mode != 0o755 else { return false }
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        return true
    }
}
