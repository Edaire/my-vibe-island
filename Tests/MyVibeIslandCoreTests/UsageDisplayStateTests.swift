import XCTest
@testable import MyVibeIslandCore

final class UsageDisplayStateTests: XCTestCase {
    func testUsageDisplayStateMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            UsageDisplayStateMatrixFixture.self,
            from: try FixtureLoader.data("usage/display-state-matrix")
        )

        let actual = UsageDisplayStateMatrixFixture(rows: [
            UsageDisplayStateMatrixRow(
                id: "hidden",
                displayState: UsageDisplayState.make(
                    snapshot: snapshot(usedPercent: 64),
                    settings: UsageSettingsSnapshot(displayStyle: .hidden),
                    providerDisplayName: "Codex"
                )
            ),
            UsageDisplayStateMatrixRow(
                id: "unavailable",
                displayState: UsageDisplayState.make(
                    snapshot: nil,
                    settings: UsageSettingsSnapshot(displayStyle: .compactHint),
                    providerDisplayName: "Codex"
                )
            ),
            UsageDisplayStateMatrixRow(
                id: "waiting",
                displayState: UsageDisplayState.make(
                    snapshot: snapshot(
                        waitingHint: UsageWaitingHint(
                            providerId: .codexRateLimits,
                            reason: .needsConfiguration,
                            severity: .warning,
                            text: "Authorize provider",
                            retryAfterSeconds: nil,
                            action: .openSettings,
                            redactedDetail: "provider setup required"
                        )
                    ),
                    settings: UsageSettingsSnapshot(displayStyle: .infoBar),
                    providerDisplayName: "Codex"
                )
            ),
            UsageDisplayStateMatrixRow(
                id: "error",
                displayState: UsageDisplayState.make(
                    snapshot: snapshot(error: .credentialMissing),
                    settings: UsageSettingsSnapshot(displayStyle: .compactHint),
                    providerDisplayName: "Kimi"
                )
            ),
            UsageDisplayStateMatrixRow(
                id: "used",
                displayState: UsageDisplayState.make(
                    snapshot: snapshot(usedPercent: 64),
                    settings: UsageSettingsSnapshot(displayStyle: .ringBadge, valueMode: .used),
                    providerDisplayName: "Codex"
                )
            ),
            UsageDisplayStateMatrixRow(
                id: "remaining",
                displayState: UsageDisplayState.make(
                    snapshot: snapshot(remaining: UsageAmount(value: 36, unit: "percent")),
                    settings: UsageSettingsSnapshot(displayStyle: .infoBar, valueMode: .remaining),
                    providerDisplayName: "Codex"
                )
            ),
            UsageDisplayStateMatrixRow(
                id: "reset-countdown",
                displayState: UsageDisplayState.make(
                    snapshot: snapshot(resetInSeconds: 5400),
                    settings: UsageSettingsSnapshot(displayStyle: .compactHint, valueMode: .resetCountdown),
                    providerDisplayName: "Codex"
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHiddenSettingsSuppressSnapshotDisplayContent() {
        let state = UsageDisplayState.make(
            snapshot: snapshot(usedPercent: 64),
            settings: UsageSettingsSnapshot(displayStyle: .hidden),
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(state.status, .hidden)
        XCTAssertEqual(state.displayStyle, .hidden)
        XCTAssertNil(state.providerId)
        XCTAssertNil(state.primaryText)
        XCTAssertNil(state.percent)
    }

    func testMissingSnapshotReturnsUnavailableState() {
        let state = UsageDisplayState.make(
            snapshot: nil,
            settings: UsageSettingsSnapshot(displayStyle: .compactHint),
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(state.status, .unavailable)
        XCTAssertEqual(state.title, "Codex")
        XCTAssertEqual(state.primaryText, "Usage unavailable")
    }

    func testWaitingHintUsesStructuredText() {
        let state = UsageDisplayState.make(
            snapshot: snapshot(
                waitingHint: UsageWaitingHint(
                    providerId: .codexRateLimits,
                    reason: .needsConfiguration,
                    severity: .warning,
                    text: "Authorize provider",
                    retryAfterSeconds: nil,
                    action: .openSettings,
                    redactedDetail: "provider setup required"
                )
            ),
            settings: UsageSettingsSnapshot(displayStyle: .infoBar),
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(state.status, .waiting)
        XCTAssertEqual(state.primaryText, "Authorize provider")
        XCTAssertEqual(state.freshness, .fresh)
    }

    func testErrorStateUsesFailureCategory() {
        let state = UsageDisplayState.make(
            snapshot: snapshot(error: .credentialMissing),
            settings: UsageSettingsSnapshot(displayStyle: .compactHint),
            providerDisplayName: "Kimi"
        )

        XCTAssertEqual(state.status, .error)
        XCTAssertEqual(state.primaryText, "credentialMissing")
    }

    func testUsedModeDisplaysPrimaryUsedPercent() {
        let state = UsageDisplayState.make(
            snapshot: snapshot(usedPercent: 64),
            settings: UsageSettingsSnapshot(displayStyle: .ringBadge, valueMode: .used),
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(state.status, .available)
        XCTAssertEqual(state.title, "Codex")
        XCTAssertEqual(state.primaryText, "64% used")
        XCTAssertEqual(state.percent, 64)
    }

    func testRemainingModeDisplaysRemainingAmount() {
        let state = UsageDisplayState.make(
            snapshot: snapshot(remaining: UsageAmount(value: 36, unit: "percent")),
            settings: UsageSettingsSnapshot(displayStyle: .infoBar, valueMode: .remaining),
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(state.primaryText, "36 percent remaining")
    }

    func testResetCountdownModeDisplaysResetSeconds() {
        let state = UsageDisplayState.make(
            snapshot: snapshot(resetInSeconds: 5400),
            settings: UsageSettingsSnapshot(displayStyle: .compactHint, valueMode: .resetCountdown),
            providerDisplayName: "Codex"
        )

        XCTAssertEqual(state.primaryText, "Resets in 5400s")
    }

    func testUsageInfoBarDerivesFromDisplayStateAndRoundTripsThroughJSON() throws {
        let displayState = UsageDisplayState(
            status: .available,
            providerDisplayName: "Codex",
            displayStyle: .infoBar,
            valueMode: .used,
            title: "Codex",
            primaryText: "64% used",
            secondaryText: "Resets soon",
            percent: 64,
            freshness: .fresh
        )

        let infoBar = UsageInfoBar.make(displayState: displayState)
        let data = try JSONEncoder().encode(infoBar)
        let decoded = try JSONDecoder().decode(UsageInfoBar.self, from: data)

        XCTAssertEqual(decoded, infoBar)
        XCTAssertEqual(decoded.status, .available)
        XCTAssertEqual(decoded.title, "Codex")
        XCTAssertEqual(decoded.primaryText, "64% used")
        XCTAssertEqual(decoded.secondaryText, "Resets soon")
        XCTAssertEqual(decoded.providerDisplayName, "Codex")
    }

    func testUsageRingBadgeDerivesFromDisplayStateAndRoundTripsThroughJSON() throws {
        let displayState = UsageDisplayState(
            status: .available,
            providerDisplayName: "Codex",
            displayStyle: .ringBadge,
            valueMode: .used,
            title: "Codex",
            primaryText: "64% used",
            percent: 64,
            freshness: .fresh
        )

        let ringBadge = UsageRingBadge.make(displayState: displayState)
        let data = try JSONEncoder().encode(ringBadge)
        let decoded = try JSONDecoder().decode(UsageRingBadge.self, from: data)

        XCTAssertEqual(decoded, ringBadge)
        XCTAssertEqual(decoded.status, .available)
        XCTAssertEqual(decoded.title, "Codex")
        XCTAssertEqual(decoded.percent, 64)
        XCTAssertEqual(decoded.providerDisplayName, "Codex")
    }

    private func snapshot(
        usedPercent: Double? = 64,
        remaining: UsageAmount? = nil,
        resetInSeconds: Int? = nil,
        waitingHint: UsageWaitingHint? = nil,
        error: UsageFailureCategory? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: .codexRateLimits,
            source: .providerReported,
            freshness: .fresh,
            primaryWindow: UsageLimitWindow(
                id: "primary",
                label: "Primary",
                kind: .fiveHour,
                remaining: remaining,
                usedPercent: usedPercent,
                resetInSeconds: resetInSeconds,
                sourceConfidence: .providerReported
            ),
            waitingHint: waitingHint,
            error: error,
            privacyLevel: .redacted
        )
    }

    private struct UsageDisplayStateMatrixFixture: Codable, Equatable {
        let rows: [UsageDisplayStateMatrixRow]
    }

    private struct UsageDisplayStateMatrixRow: Codable, Equatable {
        let id: String
        let displayState: UsageDisplayState
    }
}
