import Foundation
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandSettingsModelsTests: XCTestCase {
    @MainActor
    func testModelUsesUsageSnapshotWhenShowUsagePreferenceIsAbsent() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MyVibeIslandSettingsModelsTests.\(UUID().uuidString)"))
        let store = SettingsStore(fileURL: temporaryStoreURL())
        store.replaceSnapshot(SettingsSnapshot(usage: UsageSettingsSnapshot(displayStyle: .hidden)))

        let model = MyVibeIslandSettingsModel(
            preferences: LocalPreferenceStore(defaults: defaults),
            settingsStore: store
        )

        XCTAssertFalse(model.showUsage)
    }

    @MainActor
    func testModelPersistsGeneralIntegrationUsageLabsAndAboutPreferences() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MyVibeIslandSettingsModelsTests.\(UUID().uuidString)"))
        let preferences = LocalPreferenceStore(defaults: defaults)
        let storeURL = temporaryStoreURL()
        let model = MyVibeIslandSettingsModel(
            preferences: preferences,
            settingsStore: SettingsStore(fileURL: storeURL)
        )

        model.idleTimeoutHours = 4
        model.autoConfigureNewlyDetectedCLIs = false
        model.disableClaudeNativeTitle = false
        model.usageValueMode = .remaining
        model.usageThresholdPercent = 73
        model.usageThresholdAlert = true
        model.showUsage = false
        model.cursorApproval = "never"
        model.codexApprovalMode = "hide"
        model.kiroPermissionHintDelaySeconds = 10
        model.receiveBetaUpdates = true
        model.autoModeInsteadOfBypass = true
        model.deferClaudeApprovalsToNative = true
        model.memoryRestartEnabled = true

        XCTAssertEqual(defaults.double(forKey: "idleFallbackTimeoutHours"), 4)
        XCTAssertEqual(defaults.object(forKey: "autoConfigureNewlyDetectedCLIs") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "disableClaudeNativeTitle") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "showUsage") as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: "cursorApproval"), "never")
        XCTAssertEqual(defaults.string(forKey: "codexApprovalMode"), "hide")
        XCTAssertEqual(defaults.integer(forKey: "kiroPermissionHintDelaySeconds"), 10)
        XCTAssertEqual(defaults.object(forKey: "receiveBetaUpdates") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "autoModeInsteadOfBypass") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "deferClaudeApprovalsToNative") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "memoryRestartEnabled") as? Bool, true)
        XCTAssertNil(defaults.object(forKey: "analyticsEnabled"))

        let usage = SettingsStore(fileURL: storeURL).loadSnapshot().usage
        XCTAssertEqual(usage.valueMode, .remaining)
        XCTAssertEqual(usage.thresholdPercent, 73)
        XCTAssertTrue(usage.thresholdPeeksEnabled)
        XCTAssertEqual(usage.displayStyle, .hidden)
    }

    @MainActor
    func testGeneralAndSoundPanesInitializeResolvedStateFromInjectedStores() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "MyVibeIslandSettingsModelsTests.\(UUID().uuidString)"))
        let preferences = LocalPreferenceStore(defaults: defaults)
        preferences.set(8.0, forKey: "idleFallbackTimeoutHours")
        let model = MyVibeIslandSettingsModel(
            preferences: preferences,
            settingsStore: SettingsStore(fileURL: temporaryStoreURL())
        )
        let soundStore = SoundPreferencesStore(defaults: defaults)
        soundStore.saveManagerSettings(SoundManagerSettings(
            selectedPackId: "pack-2",
            isEnabled: false,
            volume: 0.6,
            quietHoursEnabled: true,
            quietHoursStartMinutes: 20 * 60,
            quietHoursEndMinutes: 5 * 60
        ))

        let generalFields = fields(GeneralSettingsPane(viewModel: model))
        let soundFields = fields(SoundSettingsPane(store: soundStore))

        XCTAssertEqual(try XCTUnwrap(generalFields["_idleTimeoutHours"] as? State<Double>).wrappedValue, 8)
        XCTAssertFalse(try XCTUnwrap(soundFields["_isEnabled"] as? State<Bool>).wrappedValue)
        XCTAssertEqual(try XCTUnwrap(soundFields["_volume"] as? State<Float>).wrappedValue, 0.6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(soundFields["_selectedPackId"] as? State<String?>).wrappedValue, "pack-2")
        XCTAssertTrue(try XCTUnwrap(soundFields["_quietHoursEnabled"] as? State<Bool>).wrappedValue)
    }

    @MainActor
    func testModelRefreshesTypedIntegrationSnapshotFromReadOnlyController() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandSettingsModelsTests.\(UUID().uuidString)"
        ))
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController(
            state: IntegrationCoordinatorState(rows: [
                IntegrationStatusRow(
                    sourceId: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    installState: .notInstalled,
                    healthState: .unknown
                )
            ]),
            refreshIntegrations: { timestamp, _ in
                IntegrationCoordinatorState(rows: [
                    IntegrationStatusRow(
                        sourceId: "codex",
                        displayName: "Codex CLI",
                        supportLevel: .supported,
                        installState: .needsRepair,
                        healthState: .failed,
                        repairAction: "repair",
                        diagnostics: ["configMalformed"]
                    )
                ], lastCheckedAt: timestamp)
            }
        )
        let model = MyVibeIslandSettingsModel(
            preferences: LocalPreferenceStore(defaults: defaults),
            settingsStore: SettingsStore(fileURL: temporaryStoreURL()),
            integrationController: controller
        )

        let snapshot = model.refreshIntegrations(at: "2026-07-18T00:00:00Z")

        XCTAssertEqual(snapshot.rows.first?.sourceId, "codex")
        XCTAssertEqual(snapshot.rows.first?.hookStatus, .needsRepair)
        XCTAssertEqual(snapshot.rows.first?.watcherStatus, .failed)
        XCTAssertEqual(snapshot.lastCheckedAt, "2026-07-18T00:00:00Z")
        XCTAssertEqual(model.integrationSnapshot, snapshot)
    }

    @MainActor
    func testIntegrationsPaneResolvesHookStatusesIntoExistingIDAStateSlot() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandSettingsModelsTests.\(UUID().uuidString)"
        ))
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController(
            state: IntegrationCoordinatorState(rows: []),
            refreshIntegrations: { timestamp, _ in
                IntegrationCoordinatorState(rows: [
                    IntegrationStatusRow(
                        sourceId: "codex",
                        displayName: "Codex CLI",
                        supportLevel: .supported,
                        installState: .needsRepair,
                        healthState: .failed,
                        repairAction: "repair",
                        diagnostics: ["configMalformed"]
                    )
                ], lastCheckedAt: timestamp)
            }
        )
        let model = MyVibeIslandSettingsModel(
            preferences: LocalPreferenceStore(defaults: defaults),
            settingsStore: SettingsStore(fileURL: temporaryStoreURL()),
            integrationController: controller
        )

        let paneFields = fields(IntegrationsSettingsPane(viewModel: model))
        let statuses = try XCTUnwrap(
            paneFields["_hookStatuses"] as? State<[IntegrationSettingsRow]>
        ).wrappedValue

        XCTAssertEqual(statuses.map(\.sourceId), ["codex"])
        XCTAssertEqual(statuses.first?.hookStatus, .needsRepair)
        XCTAssertEqual(statuses.first?.watcherStatus, .failed)
    }

    @MainActor
    func testModelRunsExplicitIntegrationOperationThenRefreshesSnapshot() throws {
        let defaults = try XCTUnwrap(UserDefaults(
            suiteName: "MyVibeIslandSettingsModelsTests.\(UUID().uuidString)"
        ))
        var events: [String] = []
        var installed = false
        let controller = MyVibeIslandAppKitIntegrationCoordinatorController(
            coordinator: IntegrationCoordinator(registry: AgentRegistry(descriptors: [
                AgentDescriptor(
                    id: "codex",
                    displayName: "Codex CLI",
                    supportLevel: .supported,
                    defaultEventSources: ["hooks"]
                )
            ])),
            refreshIntegrations: { timestamp, _ in
                events.append("refresh:\(timestamp)")
                return IntegrationCoordinatorState(rows: [
                    IntegrationStatusRow(
                        sourceId: "codex",
                        displayName: "Codex CLI",
                        supportLevel: .supported,
                        installState: installed ? .installed : .notInstalled,
                        healthState: installed ? .healthy : .unknown
                    )
                ], lastCheckedAt: timestamp)
            },
            installIntegration: { sourceId in
                events.append("install:\(sourceId)")
                installed = true
                return IntegrationRepairResult(
                    integrationId: sourceId,
                    operation: .install,
                    outcome: .succeeded,
                    message: "installed",
                    hookStatusBefore: .notInstalled,
                    hookStatusAfter: .installed
                )
            }
        )
        let model = MyVibeIslandSettingsModel(
            preferences: LocalPreferenceStore(defaults: defaults),
            settingsStore: SettingsStore(fileURL: temporaryStoreURL()),
            integrationController: controller
        )

        let result = model.installIntegration(
            sourceId: "codex",
            at: "2026-07-18T01:00:00Z"
        )

        XCTAssertEqual(result?.operation, .install)
        XCTAssertEqual(result?.outcome, .succeeded)
        XCTAssertEqual(model.integrationSnapshot.rows.first?.hookStatus, .installed)
        XCTAssertEqual(events, ["install:codex", "refresh:2026-07-18T01:00:00Z"])
    }

    private func fields<T>(_ value: T) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: Mirror(reflecting: value).children.compactMap {
            guard let label = $0.label else { return nil }
            return (label, $0.value)
        })
    }

    private func temporaryStoreURL() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-settings-model-tests")
            .appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("settings.json")
    }
}
