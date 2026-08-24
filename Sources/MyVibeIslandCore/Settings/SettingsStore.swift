import Foundation
import MyVibeIslandShared

public struct SettingsSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let behaviour: BehaviourSettings
    public let shortcuts: ShortcutSettings
    public let usage: UsageSettingsSnapshot
    public let labs: LabsAvailability

    public init(
        schemaVersion: Int = 1,
        behaviour: BehaviourSettings = BehaviourSettings(),
        shortcuts: ShortcutSettings = ShortcutSettings(),
        usage: UsageSettingsSnapshot = UsageSettingsSnapshot(),
        labs: LabsAvailability = LabsAvailability()
    ) {
        self.schemaVersion = max(schemaVersion, 1)
        self.behaviour = behaviour
        self.shortcuts = shortcuts
        self.usage = usage
        self.labs = labs
    }
}

public final class SettingsStore: @unchecked Sendable {
    private let lock = NSLock()
    private let fileURL: URL
    private var snapshot: SettingsSnapshot
    private var storedError: Error?

    public var lastError: Error? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return storedError
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL

        do {
            let data = try Data(contentsOf: fileURL)
            snapshot = try JSONDecoder().decode(SettingsSnapshot.self, from: data)
            storedError = nil
        } catch CocoaError.fileReadNoSuchFile {
            snapshot = SettingsSnapshot()
            storedError = nil
        } catch {
            snapshot = SettingsSnapshot()
            storedError = error
        }
    }

    public static func defaultFileURL(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/MyVibeIsland")
            .appendingPathComponent("settings.json")
    }

    public func loadSnapshot() -> SettingsSnapshot {
        lock.lock()
        defer {
            lock.unlock()
        }

        return snapshot
    }

    public func replaceSnapshot(_ snapshot: SettingsSnapshot) {
        lock.lock()
        defer {
            lock.unlock()
        }

        if persistLocked(snapshot) {
            self.snapshot = snapshot
        }
    }

    @discardableResult
    public func updateSnapshot(
        _ transform: (SettingsSnapshot) -> SettingsSnapshot
    ) -> SettingsSnapshot {
        lock.lock()
        defer {
            lock.unlock()
        }

        let candidate = transform(snapshot)
        if persistLocked(candidate) {
            snapshot = candidate
        }
        return snapshot
    }

    private func persistLocked(_ candidate: SettingsSnapshot) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(candidate).write(to: fileURL, options: .atomic)
            storedError = nil
            return true
        } catch {
            storedError = error
            return false
        }
    }
}
