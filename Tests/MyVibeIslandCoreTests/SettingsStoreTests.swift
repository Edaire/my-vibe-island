import XCTest
@testable import MyVibeIslandCore

final class SettingsStoreTests: XCTestCase {
    func testSettingsStoreMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SettingsStoreMatrixFixture.self,
            from: try FixtureLoader.data("settings/settings-store-matrix")
        )

        let missingURL = temporaryStoreURL()
        let missingStore = SettingsStore(fileURL: missingURL)
        let missingSnapshot = missingStore.loadSnapshot()

        let persistedURL = temporaryStoreURL()
        let persistedStore = SettingsStore(fileURL: persistedURL)
        let customSnapshot = SettingsSnapshot(
            schemaVersion: 0,
            behaviour: BehaviourSettings(
                showSubagents: false,
                hoverToExpandEnabled: false,
                hoverExpandDelay: 8.0,
                transientRevealDwellSeconds: -2.0,
                autoExpandOnTaskComplete: false,
                autoExpandOnAgentTeamComplete: false,
                disableClickToJump: true
            ),
            shortcuts: ShortcutSettings(
                keyboardShortcutsEnabled: false,
                persistentHotKeyIds: ["toggle", "focus"],
                switcherKeyCombo: KeyCombo(keyCode: 49, characters: "Space", modifiers: [.command, .shift])
            ),
            usage: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .ringBadge,
                valueMode: .remaining,
                thresholdPeeksEnabled: true,
                thresholdPercent: 120,
                usageNotificationsEnabled: false,
                usageSoundEnabled: true,
                labsProviderIds: [.zaiQuota, .localParsedUsage]
            ),
            labs: LabsAvailability(
                toolAvailability: LabsToolAvailability(hasClaude: true, hasCodex: true),
                gates: [
                    .autoPermissionBypass: LabsGate(toolId: .claude),
                    .experimentalKiroSupport: LabsGate(toolId: .kiro, isEnabled: false, reason: .userDisabled),
                ],
                lastCheckedAt: "2026-07-08T17:20:00Z"
            )
        )
        persistedStore.replaceSnapshot(customSnapshot)
        let reloadedSnapshot = SettingsStore(fileURL: persistedURL).loadSnapshot()

        let defaultURL = SettingsStore.defaultFileURL(
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )
        let actual = SettingsStoreMatrixFixture(
            snapshots: [
                snapshotFixture(id: "missing-file-default", snapshot: missingSnapshot),
                snapshotFixture(id: "custom-persisted-reload", snapshot: reloadedSnapshot),
            ],
            storeRows: [
                SettingsStoreRow(
                    id: "missing-file",
                    fileExistsAfterLoad: FileManager.default.fileExists(atPath: missingURL.path),
                    hasLastError: missingStore.lastError != nil
                ),
                SettingsStoreRow(
                    id: "persisted-reload",
                    fileExistsAfterLoad: FileManager.default.fileExists(atPath: persistedURL.path),
                    hasLastError: persistedStore.lastError != nil
                ),
            ],
            defaultPath: defaultURL.path
        )

        XCTAssertEqual(actual, expected)
    }

    func testMissingSettingsFileLoadsDefaultSnapshotWithoutCreatingFile() {
        let url = temporaryStoreURL()
        let store = SettingsStore(fileURL: url)

        XCTAssertEqual(store.loadSnapshot(), SettingsSnapshot())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(store.lastError)
    }

    func testReplaceSnapshotWritesJSONLoadedByNewStoreInstance() {
        let url = temporaryStoreURL()
        let store = SettingsStore(fileURL: url)
        let snapshot = SettingsSnapshot(
            schemaVersion: 2,
            behaviour: BehaviourSettings(
                showSubagents: false,
                hoverToExpandEnabled: false,
                disableClickToJump: true
            ),
            shortcuts: ShortcutSettings(keyboardShortcutsEnabled: false),
            usage: UsageSettingsSnapshot(
                preferredProviderId: .codexRateLimits,
                displayStyle: .ringBadge,
                valueMode: .remaining
            ),
            labs: LabsAvailability(
                toolAvailability: LabsToolAvailability(hasCodex: true),
                lastCheckedAt: "2026-07-08T17:20:00Z"
            )
        )

        store.replaceSnapshot(snapshot)

        let reloaded = SettingsStore(fileURL: url)
        XCTAssertEqual(reloaded.loadSnapshot(), snapshot)
        XCTAssertNil(store.lastError)
    }

    func testUpdateSnapshotPersistsFocusedChangesWithoutLosingEarlierUpdates() {
        let url = temporaryStoreURL()
        let store = SettingsStore(fileURL: url)

        store.updateSnapshot { snapshot in
            SettingsSnapshot(
                schemaVersion: snapshot.schemaVersion,
                behaviour: BehaviourSettings(
                    showSubagents: false,
                    hoverToExpandEnabled: snapshot.behaviour.hoverToExpandEnabled,
                    hoverExpandDelay: snapshot.behaviour.hoverExpandDelay,
                    autoCollapseOnMouseLeave: snapshot.behaviour.autoCollapseOnMouseLeave,
                    transientRevealDwellSeconds: snapshot.behaviour.transientRevealDwellSeconds,
                    dismissTransientRevealOnOutsideClick: snapshot.behaviour.dismissTransientRevealOnOutsideClick,
                    autoExpandOnTaskComplete: snapshot.behaviour.autoExpandOnTaskComplete,
                    autoExpandOnAgentTeamComplete: snapshot.behaviour.autoExpandOnAgentTeamComplete,
                    disableClickToJump: snapshot.behaviour.disableClickToJump
                ),
                shortcuts: snapshot.shortcuts,
                usage: snapshot.usage,
                labs: snapshot.labs
            )
        }
        let updated = store.updateSnapshot { snapshot in
            SettingsSnapshot(
                schemaVersion: snapshot.schemaVersion,
                behaviour: snapshot.behaviour,
                shortcuts: snapshot.shortcuts,
                usage: UsageSettingsSnapshot(
                    preferredProviderId: snapshot.usage.preferredProviderId,
                    displayStyle: snapshot.usage.displayStyle,
                    valueMode: .remaining,
                    thresholdPeeksEnabled: snapshot.usage.thresholdPeeksEnabled,
                    thresholdPercent: snapshot.usage.thresholdPercent,
                    usageNotificationsEnabled: snapshot.usage.usageNotificationsEnabled,
                    usageSoundEnabled: snapshot.usage.usageSoundEnabled,
                    labsProviderIds: snapshot.usage.labsProviderIds
                ),
                labs: snapshot.labs
            )
        }

        XCTAssertFalse(updated.behaviour.showSubagents)
        XCTAssertEqual(updated.usage.valueMode, .remaining)
        XCTAssertEqual(SettingsStore(fileURL: url).loadSnapshot(), updated)
    }

    func testDefaultFileURLUsesApplicationSupportPathUnderSuppliedHomeDirectory() {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-settings-home")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: home)
        }

        let url = SettingsStore.defaultFileURL(homeDirectory: home)

        XCTAssertEqual(
            url.path,
            home.appendingPathComponent("Library/Application Support/MyVibeIsland/settings.json").path
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    func testMalformedJSONLoadsDefaultSnapshotAndRecordsError() throws {
        let url = temporaryStoreURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{ "schemaVersion": "#.utf8).write(to: url)

        let store = SettingsStore(fileURL: url)

        XCTAssertEqual(store.loadSnapshot(), SettingsSnapshot())
        XCTAssertNotNil(store.lastError)
    }

    private func temporaryStoreURL() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-settings-store-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root.appendingPathComponent("settings.json")
    }

    private func snapshotFixture(id: String, snapshot: SettingsSnapshot) -> SettingsSnapshotFixture {
        SettingsSnapshotFixture(
            id: id,
            schemaVersion: snapshot.schemaVersion,
            behaviour: BehaviourFixture(
                showSubagents: snapshot.behaviour.showSubagents,
                hoverToExpandEnabled: snapshot.behaviour.hoverToExpandEnabled,
                hoverExpandDelay: snapshot.behaviour.hoverExpandDelay,
                transientRevealDwellSeconds: snapshot.behaviour.transientRevealDwellSeconds,
                autoExpandOnTaskComplete: snapshot.behaviour.autoExpandOnTaskComplete,
                autoExpandOnAgentTeamComplete: snapshot.behaviour.autoExpandOnAgentTeamComplete,
                disableClickToJump: snapshot.behaviour.disableClickToJump
            ),
            shortcuts: ShortcutsFixture(
                keyboardShortcutsEnabled: snapshot.shortcuts.keyboardShortcutsEnabled,
                persistentHotKeyIds: snapshot.shortcuts.persistentHotKeyIds,
                switcherDisplayText: snapshot.shortcuts.switcherKeyCombo?.displayText
            ),
            usage: UsageFixture(
                preferredProviderId: snapshot.usage.preferredProviderId?.rawValue,
                displayStyle: snapshot.usage.displayStyle.rawValue,
                valueMode: snapshot.usage.valueMode.rawValue,
                thresholdPeeksEnabled: snapshot.usage.thresholdPeeksEnabled,
                thresholdPercent: snapshot.usage.thresholdPercent,
                usageNotificationsEnabled: snapshot.usage.usageNotificationsEnabled,
                usageSoundEnabled: snapshot.usage.usageSoundEnabled,
                labsProviderIds: snapshot.usage.labsProviderIds.map(\.rawValue).sorted()
            ),
            labs: LabsFixture(
                availableToolIds: snapshot.labs.availableToolIds.map(\.rawValue),
                disabledGateCount: snapshot.labs.diagnosticSummary.disabledGateCount,
                codexUsageGateAvailable: snapshot.labs.isGateAvailable(.codexExperimentalUsage),
                kiroSupportGateAvailable: snapshot.labs.isGateAvailable(.experimentalKiroSupport),
                lastCheckedAt: snapshot.labs.lastCheckedAt
            )
        )
    }

    private struct SettingsStoreMatrixFixture: Codable, Equatable {
        let snapshots: [SettingsSnapshotFixture]
        let storeRows: [SettingsStoreRow]
        let defaultPath: String
    }

    private struct SettingsStoreRow: Codable, Equatable {
        let id: String
        let fileExistsAfterLoad: Bool
        let hasLastError: Bool
    }

    private struct SettingsSnapshotFixture: Codable, Equatable {
        let id: String
        let schemaVersion: Int
        let behaviour: BehaviourFixture
        let shortcuts: ShortcutsFixture
        let usage: UsageFixture
        let labs: LabsFixture
    }

    private struct BehaviourFixture: Codable, Equatable {
        let showSubagents: Bool
        let hoverToExpandEnabled: Bool
        let hoverExpandDelay: Double
        let transientRevealDwellSeconds: Double
        let autoExpandOnTaskComplete: Bool
        let autoExpandOnAgentTeamComplete: Bool
        let disableClickToJump: Bool
    }

    private struct ShortcutsFixture: Codable, Equatable {
        let keyboardShortcutsEnabled: Bool
        let persistentHotKeyIds: [String]
        let switcherDisplayText: String?
    }

    private struct UsageFixture: Codable, Equatable {
        let preferredProviderId: String?
        let displayStyle: String
        let valueMode: String
        let thresholdPeeksEnabled: Bool
        let thresholdPercent: Int
        let usageNotificationsEnabled: Bool
        let usageSoundEnabled: Bool
        let labsProviderIds: [String]
    }

    private struct LabsFixture: Codable, Equatable {
        let availableToolIds: [String]
        let disabledGateCount: Int
        let codexUsageGateAvailable: Bool
        let kiroSupportGateAvailable: Bool
        let lastCheckedAt: String?
    }
}
