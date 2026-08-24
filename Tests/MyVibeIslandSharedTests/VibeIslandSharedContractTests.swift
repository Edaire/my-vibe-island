import Foundation
import Testing
@testable import MyVibeIslandShared

@Suite("Vibe Island shared contract")
struct VibeIslandSharedContractTests {
    @Test
    func runtimeHomeDirectoryUsesExplicitStateFixtureOverride() {
        let resolved = VibeIslandStateRoot.runtimeHomeDirectory(
            processEnvironment: [
                VibeIslandStateRoot.stateHomeEnvironmentVariable: "/private/tmp/vibe-island-motion-fixture"
            ],
            fallback: URL(fileURLWithPath: "/Users/reference", isDirectory: true)
        )

        #expect(resolved.path == "/private/tmp/vibe-island-motion-fixture")
    }

    @Test
    func runtimeHomeDirectoryRejectsRelativeOrBlankFixtureOverride() {
        let fallback = URL(fileURLWithPath: "/Users/reference", isDirectory: true)

        #expect(VibeIslandStateRoot.runtimeHomeDirectory(
            processEnvironment: [VibeIslandStateRoot.stateHomeEnvironmentVariable: ""],
            fallback: fallback
        ) == fallback)
        #expect(VibeIslandStateRoot.runtimeHomeDirectory(
            processEnvironment: [VibeIslandStateRoot.stateHomeEnvironmentVariable: "relative/fixture"],
            fallback: fallback
        ) == fallback)
    }

    @Test
    func stateFixtureIsEnabledOnlyForAnAbsoluteStateHomeOverride() {
        #expect(VibeIslandStateRoot.isStateFixtureEnabled(
            processEnvironment: [VibeIslandStateRoot.stateHomeEnvironmentVariable: "/private/tmp/fixture"]
        ))
        #expect(!VibeIslandStateRoot.isStateFixtureEnabled(
            processEnvironment: [VibeIslandStateRoot.stateHomeEnvironmentVariable: "fixture"]
        ))
    }

    @Test
    func runtimeHomeDirectoryAcceptsExplicitAppLaunchArgument() {
        let resolved = VibeIslandStateRoot.runtimeHomeDirectory(
            processEnvironment: [:],
            processArguments: ["vibe-island", "--state-home", "/private/tmp/launch-fixture"],
            fallback: URL(fileURLWithPath: "/Users/reference", isDirectory: true)
        )

        #expect(resolved.path == "/private/tmp/launch-fixture")
        #expect(VibeIslandStateRoot.isStateFixtureEnabled(
            processEnvironment: [:],
            processArguments: ["vibe-island", "--state-home", "/private/tmp/launch-fixture"]
        ))
    }

    @Test
    func stateRootUsesSingleApplicationSupportNamespace() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let root = VibeIslandStateRoot(homeDirectory: home)

        #expect(root.appSupportDir.path == "/tmp/home/Library/Application Support/MyVibeIsland")
        #expect(root.sessionStoreURL.path == "/tmp/home/Library/Application Support/MyVibeIsland/sessions.json")
        #expect(root.terminalSessionMapURL.path == "/tmp/home/Library/Application Support/MyVibeIsland/session-terminals.json")
        #expect(root.legacyTerminalSessionMapURL.path == "/tmp/home/Library/Application Support/vibe-island/session-terminals.json")
        #expect(root.logsDir.path == "/tmp/home/Library/Application Support/MyVibeIsland/logs")
        #expect(root.admissionRulesURL.path == "/tmp/home/Library/Application Support/MyVibeIsland/admission-rules.json")
        #expect(root.admissionRejectionsURL.path == "/tmp/home/Library/Application Support/MyVibeIsland/session-admission-rejections.json")
        #expect(root.gitIdentityCacheDir.path == "/tmp/home/Library/Application Support/MyVibeIsland/cache/git-identity")
        #expect(root.terminalSessionMapReadURLs.map(\.path) == [
            "/tmp/home/Library/Application Support/MyVibeIsland/session-terminals.json",
            "/tmp/home/Library/Application Support/vibe-island/session-terminals.json",
        ])
    }

    @Test
    func terminalSessionMapEntryKeepsBridgeAndIslandFieldsTogether() throws {
        let entry = TerminalSessionMapEntry(
            source: "codex",
            status: "running_tool",
            currentTool: "bash",
            toolTarget: "swift test",
            cwd: "/repo",
            firstUserMessage: "start",
            lastUserMessage: "continue",
            lastAssistantMessage: "short",
            lastAssistantMessageFull: "full output",
            codexRolloutPath: "/rollout.jsonl",
            lastActivityAt: 42,
            bundleIdentifier: "com.apple.Terminal",
            termProgram: "tmux",
            tty: "ttys001",
            isInTmux: true,
            tmuxPane: "%1",
            tmuxSocketPath: "/tmp/tmux.sock",
            termSessionId: "terminal-session",
            codexNotifyThreadId: "thread"
        )

        let decoded = try JSONDecoder().decode(
            TerminalSessionMapEntry.self,
            from: try JSONEncoder().encode(entry)
        )

        #expect(decoded == entry)
    }

    @Test
    func cwdAdmissionPolicyMatchesEnabledPrefixAndContainsRules() {
        let rules = [
            CwdAdmissionRule(
                pattern: "/private/tmp",
                matchType: .prefix,
                displayName: "temp",
                reason: "scratch",
                isEnabled: true
            ),
            CwdAdmissionRule(
                pattern: "/node_modules/",
                matchType: .contains,
                displayName: "dependency",
                reason: nil,
                isEnabled: true
            ),
            CwdAdmissionRule(
                pattern: "/exact/probe",
                matchType: .equals,
                displayName: nil,
                reason: "exact probe",
                isEnabled: true
            ),
            CwdAdmissionRule(
                pattern: "/ignored",
                matchType: .prefix,
                displayName: nil,
                reason: nil,
                isEnabled: false
            ),
        ]

        #expect(CwdAdmissionPolicy.matchDeniedCwd("/private/tmp/repo", userRules: rules)?.pattern == "/private/tmp")
        #expect(CwdAdmissionPolicy.matchDeniedCwd("/repo/node_modules/pkg", userRules: rules)?.pattern == "/node_modules/")
        #expect(CwdAdmissionPolicy.matchDeniedCwd("/exact/probe", userRules: rules)?.matchType == .equals)
        #expect(CwdAdmissionPolicy.matchDeniedCwd("/exact/probe-child", userRules: rules) == nil)
        #expect(CwdAdmissionPolicy.matchDeniedCwd("/ignored/repo", userRules: rules) == nil)
    }

    @Test
    func cwdAdmissionPolicyContainsIDABuiltInProbeRules() {
        let rules = CwdAdmissionPolicy.builtInDeniedCwdRules

        #expect(rules.contains {
            $0.pattern == "ClaudeProbe"
                && $0.matchType == .contains
                && $0.reason == "usage/status probe"
        })
        #expect(rules.contains {
            $0.pattern == "Application Support/CodexBar"
                && $0.matchType == .contains
                && $0.reason == "official health-check probe"
        })
    }

    @Test
    func appBundleAdmissionPolicyMatchesAncestorBundleIds() {
        let rules = [
            AppBundleAdmissionRule(
                bundleId: "com.apple.Terminal",
                displayName: "Terminal",
                reason: "allowed test denial",
                isEnabled: true
            ),
            AppBundleAdmissionRule(
                bundleId: "com.example.Disabled",
                displayName: nil,
                reason: nil,
                isEnabled: false
            ),
        ]

        #expect(AppBundleAdmissionPolicy.matchDeniedAncestorBundle(
            "com.apple.Terminal",
            userRules: rules
        )?.bundleId == "com.apple.Terminal")
        #expect(AppBundleAdmissionPolicy.matchDeniedAncestorBundle(
            "com.example.Disabled",
            userRules: rules
        ) == nil)
    }

    @Test
    func sessionAdmissionEvaluatorPrefersBundleThenCwdRejections() {
        let evidence = SessionAdmissionEvidence(
            cwd: "/private/tmp/repo",
            bundleIdentifiers: ["com.apple.Terminal"]
        )

        #expect(SessionAdmissionEvaluator.rejection(
            for: evidence,
            userBundleRules: [
                AppBundleAdmissionRule(bundleId: "com.apple.Terminal", reason: "bundle")
            ],
            userCwdRules: [
                CwdAdmissionRule(pattern: "/private/tmp", matchType: .prefix, reason: "cwd")
            ]
        ) == .ancestorBundle("com.apple.Terminal"))
    }

    @Test
    func syntheticUserTextFiltersHookInjectedBlocksAndUnwrapsUserQuery() {
        #expect(SyntheticUserText.isSynthetic("<environment_context>\n<data/>"))
        #expect(SyntheticUserText.isSynthetic("# AGENTS.md instructions for /repo"))
        #expect(SyntheticUserText.isSynthetic("<codex_internal_context source=\"goal\">\n<objective>"))
        #expect(SyntheticUserText.isSynthetic("<subagent_notification>\n{\"status\":\"completed\"}"))
        #expect(!SyntheticUserText.isSynthetic("real user prompt"))
        #expect(SyntheticUserText.unwrappedUserQuery("User query: fix the bridge") == "fix the bridge")
    }

    @Test
    func sessionAdmissionConfigAndLedgerRoundTripOriginalFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared-admission-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let stateRoot = VibeIslandStateRoot(homeDirectory: root)

        let rules = PersistedSessionAdmissionRulesV1(
            deniedAncestorBundles: [AppBundleAdmissionRule(bundleId: "com.example.Terminal")],
            deniedCwdPatterns: [CwdAdmissionRule(pattern: "/tmp", matchType: .prefix)]
        )
        try SessionAdmissionConfig.save(rules, to: stateRoot.admissionRulesURL)
        #expect(SessionAdmissionConfig.configURL(homeDirectory: root) == stateRoot.admissionRulesURL)
        #expect(SessionAdmissionConfig.load(from: stateRoot.admissionRulesURL) == rules)

        let now = Date(timeIntervalSinceReferenceDate: 123)
        let evidence = SessionAdmissionEvidence(
            cwd: "/tmp/project",
            bundleIdentifiers: ["com.example.Terminal"]
        )
        try SessionAdmissionLedger.record(
            sessionId: "codex-1",
            evidence: evidence,
            rejection: .ancestorBundle("com.example.Terminal"),
            to: stateRoot.admissionRejectionsURL,
            now: now
        )

        let loaded = SessionAdmissionLedger.load(from: stateRoot.admissionRejectionsURL, now: now)
        #expect(loaded["codex-1"]?.evidence == evidence)
        #expect(loaded["codex-1"]?.rejectedAt == now)
        #expect(loaded["codex-1"]?.reason == "ancestor bundle denied: com.example.Terminal")
    }

    @Test
    func ancestorAppBundleDetectorExtractsContainingAppPath() {
        #expect(AncestorAppBundleDetector.appBundlePath(
            containing: "/Applications/Otty.app/Contents/MacOS/otty-cli"
        ) == "/Applications/Otty.app")
        #expect(AncestorAppBundleDetector.appBundlePath(containing: "/usr/bin/tmux") == nil)
    }

    @Test
    func gitIdentityResolverReportsNotGitOutsideRepository() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared-git-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: path) }

        #expect(GitIdentityResolver.resolveCached(cwd: path.path).payloadStatus == "notGitRepo")
    }

    @Test
    func ottyPaneResolverUsesExplicitSessionPaneBeforeCwdFallback() {
        #expect(OttyPaneResolver.resolveFocusedPaneIfCwdMatches(
            sessionPane: "pane-1",
            cwd: "/repo",
            socket: "/tmp/otty.sock"
        ) == "pane-1")
        #expect(OttyPaneResolver.resolveFocusedPaneIfCwdMatches(
            sessionPane: nil,
            cwd: nil,
            socket: "/tmp/otty.sock"
        ) == nil)
    }
}
