import XCTest
@testable import MyVibeIslandCore

final class SoundManagerPlaybackPlanModelsTests: XCTestCase {
    func testSoundManagerPlaybackPlansMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SoundManagerPlaybackPlanFixture.self,
            from: try FixtureLoader.data("sound/manager-playback-plans")
        )
        let manager = SoundManager(snapshot: SoundManagerSnapshot(
            settings: SoundManagerSettings(volume: 0.8),
            sourceSelections: [
                .permission: SoundSourceSelection(
                    category: .permission,
                    sourceKind: .builtin8bit,
                    soundId: "builtin8bit.permission",
                    isEnabled: true,
                    volume: 0.5,
                    cooldownSeconds: 1,
                    outputRouteBehavior: "default"
                ),
                .question: SoundSourceSelection(
                    category: .question,
                    sourceKind: .appleSystem,
                    soundId: "Ping",
                    isEnabled: true,
                    volume: 0.75,
                    cooldownSeconds: 2,
                    outputRouteBehavior: "default"
                ),
                .completion: SoundSourceSelection(
                    category: .completion,
                    sourceKind: .off,
                    soundId: nil,
                    isEnabled: false,
                    volume: 1,
                    cooldownSeconds: 0,
                    outputRouteBehavior: "default"
                ),
                .failure: SoundSourceSelection(
                    category: .failure,
                    sourceKind: .custom,
                    soundId: "custom.permission",
                    isEnabled: true,
                    volume: 0.5,
                    cooldownSeconds: 3,
                    outputRouteBehavior: "default"
                ),
                .warning: SoundSourceSelection(
                    category: .warning,
                    sourceKind: .custom,
                    soundId: "missing.custom",
                    isEnabled: true,
                    volume: 1,
                    cooldownSeconds: 4,
                    outputRouteBehavior: "default"
                ),
            ],
            customSoundStore: CustomSoundStoreSnapshot(files: [Self.permissionTone])
        ))
        let quietManager = SoundManager(snapshot: SoundManagerSnapshot(
            settings: SoundManagerSettings(
                quietHoursEnabled: true,
                quietHoursStartMinutes: 0,
                quietHoursEndMinutes: 1_439
            )
        ))

        let actual = SoundManagerPlaybackPlanFixture(
            builtinPermission: manager.planPlayback(Self.request),
            appleSystemQuestion: manager.planPlayback(SoundManagerPlaybackRequest(
                category: .question,
                source: "codex",
                minuteOfDay: 12 * 60
            )),
            sourceOffCompletion: manager.planPlayback(SoundManagerPlaybackRequest(
                category: .completion,
                source: "codex",
                minuteOfDay: 12 * 60
            )),
            customFailure: manager.planPlayback(SoundManagerPlaybackRequest(
                category: .failure,
                source: "codex",
                minuteOfDay: 12 * 60
            )),
            missingCustomWarning: manager.planPlayback(SoundManagerPlaybackRequest(
                category: .warning,
                source: "codex",
                minuteOfDay: 12 * 60
            )),
            quietPermission: quietManager.planPlayback(Self.request)
        )

        XCTAssertEqual(actual, expected)
    }

    func testSoundManagerSnapshotRoundTripsOwnedSoundState() throws {
        let snapshot = SoundManagerSnapshot(
            settings: SoundManagerSettings(selectedPackId: "builtin.clean", volume: 0.75),
            filter: SoundFilter(autoDetectProbes: true),
            sourceSelections: [
                .permission: SoundSourceSelection(
                    category: .permission,
                    sourceKind: .custom,
                    soundId: "custom.permission",
                    isEnabled: true,
                    volume: 0.8,
                    cooldownSeconds: 0,
                    outputRouteBehavior: "default"
                ),
            ],
            customSoundStore: CustomSoundStoreSnapshot(files: [Self.permissionTone]),
            outputDevice: SoundOutputDeviceSnapshot(
                id: "default",
                name: "Built-in Output",
                outputVolume: 0.6,
                observedAt: "2026-07-08T08:40:00Z"
            )
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SoundManagerSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.settings.selectedPackId, "builtin.clean")
        XCTAssertEqual(decoded.sourceSelections[.permission]?.soundId, "custom.permission")
    }

    func testSoundManagerSuppressesDisabledQuietHoursFilterAndMissingOutput() {
        let disabled = SoundManager(snapshot: SoundManagerSnapshot(settings: SoundManagerSettings(isEnabled: false)))
            .planPlayback(Self.request)
        let quiet = SoundManager(snapshot: SoundManagerSnapshot(
            settings: SoundManagerSettings(
                quietHoursEnabled: true,
                quietHoursStartMinutes: 0,
                quietHoursEndMinutes: 1_439
            )
        )).planPlayback(Self.request)
        let filtered = SoundManager(snapshot: SoundManagerSnapshot(
            filter: SoundFilter(rules: [
                SoundFilterRule(
                    id: "suppress-permission",
                    type: .category,
                    action: .suppressSound,
                    category: .permission
                ),
            ])
        )).planPlayback(Self.request)
        let missingOutput = SoundManager(snapshot: SoundManagerSnapshot(outputDevice: nil))
            .planPlayback(Self.request)

        XCTAssertEqual(disabled.action, .suppressSound)
        XCTAssertEqual(disabled.suppressedReason, .managerDisabled)
        XCTAssertEqual(quiet.suppressedReason, .quietHours)
        XCTAssertEqual(filtered.suppressedReason, .filterRule)
        XCTAssertEqual(missingOutput.suppressedReason, .outputUnavailable)
    }

    func testSoundManagerPlansCustomSoundAndFallbackForMissingCustomSound() {
        let manager = SoundManager(snapshot: SoundManagerSnapshot(
            sourceSelections: [
                .permission: SoundSourceSelection(
                    category: .permission,
                    sourceKind: .custom,
                    soundId: "custom.permission",
                    isEnabled: true,
                    volume: 0.8,
                    cooldownSeconds: 2,
                    outputRouteBehavior: "default"
                ),
                .failure: SoundSourceSelection(
                    category: .failure,
                    sourceKind: .custom,
                    soundId: "missing.custom",
                    isEnabled: true,
                    volume: 1,
                    cooldownSeconds: 0,
                    outputRouteBehavior: "default"
                ),
            ],
            customSoundStore: CustomSoundStoreSnapshot(files: [Self.permissionTone])
        ))

        let customPlan = manager.planPlayback(Self.request)
        let fallbackPlan = manager.planPlayback(SoundManagerPlaybackRequest(
            category: .failure,
            source: "codex",
            minuteOfDay: 12 * 60
        ))

        XCTAssertEqual(customPlan.action, .playCustomSound)
        XCTAssertEqual(customPlan.soundId, "custom.permission")
        XCTAssertEqual(customPlan.effectiveVolume, 0.64, accuracy: 0.0001)
        XCTAssertEqual(customPlan.cooldownSeconds, 2)
        XCTAssertEqual(fallbackPlan.action, .fallbackToSystemSound)
        XCTAssertEqual(fallbackPlan.suppressedReason, .missingCustomSound)
    }

    private static let request = SoundManagerPlaybackRequest(
        category: .permission,
        source: "codex",
        lifecycleEvent: .waiting,
        subagentState: .active,
        minuteOfDay: 12 * 60
    )

    private static let permissionTone = CustomSoundFile(
        id: "custom.permission",
        displayName: "Permission Private",
        storedFileName: "permission-private.wav",
        sourceMode: .copiedIntoLibrary,
        format: .wav,
        durationMilliseconds: 900,
        createdAtUnixSeconds: 1_782_950_400,
        playbackSettings: CustomSoundPlaybackSettings(volume: 0.8)
    )

    private struct SoundManagerPlaybackPlanFixture: Codable, Equatable {
        let builtinPermission: SoundManagerPlaybackPlan
        let appleSystemQuestion: SoundManagerPlaybackPlan
        let sourceOffCompletion: SoundManagerPlaybackPlan
        let customFailure: SoundManagerPlaybackPlan
        let missingCustomWarning: SoundManagerPlaybackPlan
        let quietPermission: SoundManagerPlaybackPlan
    }
}
