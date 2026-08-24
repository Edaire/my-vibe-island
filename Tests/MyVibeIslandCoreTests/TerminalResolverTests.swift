import XCTest
@testable import MyVibeIslandCore

final class TerminalResolverTests: XCTestCase {
    func testTerminalResolverMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalResolverMatrixFixture.self,
            from: try FixtureLoader.data("terminal/resolver-matrix")
        )
        let resolver = TerminalResolver()

        let exact = resolver.resolve(
            JumpInput(
                sessionId: "s1",
                source: "codex",
                bundleId: "com.googlecode.iterm2",
                cwd: "/tmp/project",
                itermSessionId: "iterm-1"
            ),
            provenance: .hookEnvironment
        )
        let strong = resolver.resolve(
            JumpInput(
                sessionId: "s2",
                source: "codex",
                bundleId: "com.apple.Terminal",
                tty: "/dev/ttys001"
            ),
            provenance: .windowProbe
        )
        let remoteGuard = resolver.prefer(
            stored: strong,
            candidate: resolver.resolve(
                JumpInput(
                    sessionId: "s2",
                    source: "codex",
                    sshTTY: "/dev/pts/1",
                    remoteHostId: "server-1",
                    remoteCwd: "/srv/project"
                ),
                provenance: .manualSelection
            )
        )

        let actual = TerminalResolverMatrixFixture(rows: [
            row(id: "exact-iterm-hook-environment", target: exact),
            row(id: "strong-terminal-window-probe", target: strong),
            row(id: "remote-like-unmarked-does-not-replace-local", target: remoteGuard),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testResolveAddsFingerprintFocusIdentityAndRouterMetadata() {
        let input = JumpInput(
            sessionId: "s1",
            source: "codex",
            bundleId: "com.googlecode.iterm2",
            cwd: "/tmp/project",
            itermSessionId: "iterm-1"
        )

        let resolved = TerminalResolver().resolve(input, provenance: .hookEnvironment)

        XCTAssertEqual(resolved.input.terminalFingerprint?.sessionId, "s1")
        XCTAssertEqual(resolved.input.terminalFingerprint?.itermSessionId, "iterm-1")
        XCTAssertEqual(resolved.input.terminalFocusIdentity?.confidence, .exact)
        XCTAssertEqual(resolved.input.terminalFocusIdentity?.externalSessionId, "iterm-1")
        XCTAssertEqual(resolved.strength, .exact)
        XCTAssertEqual(resolved.plannedHandlerId, "iterm")
        XCTAssertEqual(resolved.plannedPrecision, .exactPane)
        XCTAssertEqual(resolved.capabilityDescriptor?.displayName, "iTerm2")
    }

    func testStrengthClassifiesExactStrongWeakAndUnknownTargets() {
        let resolver = TerminalResolver()

        XCTAssertEqual(
            resolver.resolve(JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1")).strength,
            .exact
        )
        XCTAssertEqual(
            resolver.resolve(JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal", tty: "/dev/ttys001")).strength,
            .strong
        )
        XCTAssertEqual(
            resolver.resolve(JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project")).strength,
            .weak
        )
        XCTAssertEqual(
            resolver.resolve(JumpInput(sessionId: "s1", source: "codex")).strength,
            .unknown
        )
    }

    func testPreferKeepsStrongerTargetOverWeakerTarget() {
        let resolver = TerminalResolver()
        let stored = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", cwd: "/tmp/project"),
            provenance: .windowProbe
        )
        let candidate = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1"),
            provenance: .hookEnvironment
        )

        let preferred = resolver.prefer(stored: stored, candidate: candidate)

        XCTAssertEqual(preferred.input.tmuxPane, "%1")
        XCTAssertEqual(preferred.strength, .exact)
    }

    func testPreferUsesProvenanceWhenStrengthTies() {
        let resolver = TerminalResolver()
        let stored = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal", tty: "/dev/ttys001"),
            provenance: .hookEnvironment
        )
        let candidate = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal", tty: "/dev/ttys002"),
            provenance: .windowProbe
        )

        let preferred = resolver.prefer(stored: stored, candidate: candidate)

        XCTAssertEqual(preferred.input.tty, "/dev/ttys002")
        XCTAssertEqual(preferred.provenance, .windowProbe)
    }

    func testManualSelectionWinsWhenStrengthTies() {
        let resolver = TerminalResolver()
        let stored = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%1"),
            provenance: .hookEnvironment
        )
        let candidate = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", tmuxPane: "%2"),
            provenance: .manualSelection
        )

        let preferred = resolver.prefer(stored: stored, candidate: candidate)

        XCTAssertEqual(preferred.input.tmuxPane, "%2")
        XCTAssertEqual(preferred.provenance, .manualSelection)
    }

    func testRemoteTargetDoesNotOverwriteLocalUnlessCandidateIsRemote() {
        let resolver = TerminalResolver()
        let localStored = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", bundleId: "com.apple.Terminal", tty: "/dev/ttys001"),
            provenance: .windowProbe
        )
        let remoteLikeButUnmarked = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", sshTTY: "/dev/pts/1", remoteHostId: "server-1", remoteCwd: "/srv/project"),
            provenance: .manualSelection
        )

        XCTAssertEqual(
            resolver.prefer(stored: localStored, candidate: remoteLikeButUnmarked).input.tty,
            "/dev/ttys001"
        )

        let markedRemote = resolver.resolve(
            JumpInput(sessionId: "s1", source: "codex", isSSHRemote: true, sshTTY: "/dev/pts/1", remoteHostId: "server-1", remoteCwd: "/srv/project"),
            provenance: .manualSelection
        )

        XCTAssertEqual(
            resolver.prefer(stored: localStored, candidate: markedRemote).input.remoteHostId,
            "server-1"
        )
    }

    private func row(
        id: String,
        target: TerminalResolvedTarget
    ) -> TerminalResolverMatrixRow {
        TerminalResolverMatrixRow(
            id: id,
            provenance: target.provenance.rawValue,
            strength: target.strength.rawValue,
            plannedHandlerId: target.plannedHandlerId,
            plannedPrecision: target.plannedPrecision.rawValue,
            capabilityDisplayName: target.capabilityDescriptor?.displayName,
            diagnosticSummary: target.diagnosticSummary,
            fingerprintSessionId: target.input.terminalFingerprint?.sessionId,
            fingerprintTTY: target.input.terminalFingerprint?.tty,
            fingerprintITermSessionId: target.input.terminalFingerprint?.itermSessionId,
            focusConfidence: target.input.terminalFocusIdentity?.confidence.rawValue,
            focusExternalSessionId: target.input.terminalFocusIdentity?.externalSessionId,
            focusPaneId: target.input.terminalFocusIdentity?.paneId,
            selectedTTY: target.input.tty,
            selectedRemoteHostId: target.input.remoteHostId
        )
    }

    private struct TerminalResolverMatrixFixture: Codable, Equatable {
        let rows: [TerminalResolverMatrixRow]
    }

    private struct TerminalResolverMatrixRow: Codable, Equatable {
        let id: String
        let provenance: String
        let strength: Int
        let plannedHandlerId: String
        let plannedPrecision: String
        let capabilityDisplayName: String?
        let diagnosticSummary: String
        let fingerprintSessionId: String?
        let fingerprintTTY: String?
        let fingerprintITermSessionId: String?
        let focusConfidence: String?
        let focusExternalSessionId: String?
        let focusPaneId: String?
        let selectedTTY: String?
        let selectedRemoteHostId: String?
    }
}
