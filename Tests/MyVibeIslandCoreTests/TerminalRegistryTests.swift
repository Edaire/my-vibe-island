import XCTest
@testable import MyVibeIslandCore

final class TerminalRegistryTests: XCTestCase {
    func testDefaultRegistryMatchesCapabilityFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            TerminalRegistry.self,
            from: try FixtureLoader.data("terminal/default-capability-registry")
        )

        XCTAssertEqual(TerminalRegistry.default, expected)
    }

    func testDefaultRegistryContainsRouterHandlerIdsInPriorityOrder() {
        let ids = TerminalRegistry.default.descriptors.map(\.id)

        XCTAssertEqual(ids, [
            "custom-url",
            "codex-deeplink",
            "supacode",
            "cmux",
            "tmux",
            "zellij",
            "wezterm",
            "kaku",
            "otty",
            "kitty",
            "ghostty",
            "warp",
            "iterm",
            "terminal-tty",
            "vscode-workspace",
            "vscode-insiders-workspace",
            "cursor-workspace",
            "windsurf-workspace",
            "trae-workspace",
            "qoder-workspace",
            "jetbrains-workspace",
            "ide-workspace",
            "workspace",
            "claude-desktop-code",
            "application",
            "remote-hint",
            "unsupported"
        ])
    }

    func testDescriptorLookupsUseExactIdentifiers() {
        let registry = TerminalRegistry.default

        XCTAssertEqual(registry.descriptor(for: "tmux")?.displayName, "tmux")
        XCTAssertEqual(registry.descriptor(for: "wezterm")?.cliCommands, ["wezterm"])
        XCTAssertEqual(registry.descriptor(for: "kaku")?.cliCommands, ["kaku"])
        XCTAssertNil(registry.descriptor(for: "TMUX"))
    }

    func testBundleAndCommandLookups() {
        let registry = TerminalRegistry.default

        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.googlecode.iterm2")?.id, "iterm")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.apple.Terminal")?.id, "terminal-tty")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.mitchellh.ghostty")?.id, "ghostty")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.github.mitchellh.ghostty")?.id, "ghostty")
        XCTAssertEqual(registry.descriptor(cliCommand: "code")?.id, "vscode-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "code-insiders")?.id, "vscode-insiders-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "cursor")?.id, "cursor-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "windsurf")?.id, "windsurf-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "trae")?.id, "trae-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "qoder")?.id, "qoder-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "idea")?.id, "jetbrains-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "webstorm")?.id, "jetbrains-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.microsoft.VSCode")?.id, "vscode-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.microsoft.VSCodeInsiders")?.id, "vscode-insiders-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.todesktop.230313mzl4w4u92")?.id, "cursor-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.exafunction.windsurf")?.id, "windsurf-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.trae.app")?.id, "trae-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.jetbrains.intellij")?.id, "jetbrains-workspace")
        XCTAssertEqual(registry.descriptor(bundleIdentifier: "com.jetbrains.WebStorm")?.id, "jetbrains-workspace")
        XCTAssertEqual(registry.descriptor(cliCommand: "tmux")?.id, "tmux")
        XCTAssertEqual(registry.descriptor(cliCommand: "kaku")?.id, "kaku")
        XCTAssertNil(registry.descriptor(cliCommand: "missing-cli"))
    }

    func testPrecisionAndSupportMetadata() {
        let registry = TerminalRegistry.default

        XCTAssertEqual(registry.descriptor(for: "codex-deeplink")?.displayName, "Codex Desktop App")
        XCTAssertEqual(registry.descriptor(for: "codex-deeplink")?.category, .desktopApp)
        XCTAssertEqual(registry.descriptor(for: "codex-deeplink")?.supportedPrecisions, [.exactPane])
        XCTAssertEqual(registry.descriptor(for: "codex-deeplink")?.supportLevel, .experimental)
        let ideDescriptorIds = [
            "vscode-workspace",
            "vscode-insiders-workspace",
            "cursor-workspace",
            "windsurf-workspace",
            "trae-workspace",
            "qoder-workspace",
            "jetbrains-workspace"
        ]

        for id in ideDescriptorIds {
            XCTAssertEqual(registry.descriptor(for: id)?.category, .ide)
            XCTAssertEqual(registry.descriptor(for: id)?.supportedPrecisions, [.workspace])
            XCTAssertTrue(registry.descriptor(for: id)?.isWorkspaceLevel == true)
        }

        XCTAssertEqual(registry.descriptor(for: "trae-workspace")?.supportLevel, .experimental)
        XCTAssertEqual(registry.descriptor(for: "qoder-workspace")?.supportLevel, .experimental)
        XCTAssertEqual(registry.descriptor(for: "vscode-workspace")?.supportLevel, .supported)
        XCTAssertEqual(registry.descriptor(for: "jetbrains-workspace")?.supportLevel, .supported)
        XCTAssertEqual(registry.descriptor(for: "tmux")?.supportedPrecisions, [.exactPane])
        XCTAssertEqual(registry.descriptor(for: "kaku")?.supportedPrecisions, [.exactPane])
        XCTAssertEqual(registry.descriptor(for: "kaku")?.supportLevel, .experimental)
        XCTAssertEqual(registry.descriptor(for: "kitty")?.supportedPrecisions, [.exactWindow])
        XCTAssertEqual(registry.descriptor(for: "ghostty")?.supportedPrecisions, [.exactWindow])
        XCTAssertEqual(registry.descriptor(for: "ghostty")?.supportLevel, .supported)
        XCTAssertEqual(registry.descriptor(for: "ide-workspace")?.supportedPrecisions, [.workspace])
        XCTAssertEqual(registry.descriptor(for: "remote-hint")?.supportedPrecisions, [.remoteHint])
        XCTAssertEqual(registry.descriptor(for: "unsupported")?.supportedPrecisions, [.unsupported])
        XCTAssertEqual(registry.descriptor(for: "claude-desktop-code")?.displayName, "Claude Desktop Code")
        XCTAssertEqual(registry.descriptor(for: "claude-desktop-code")?.category, .desktopApp)
        XCTAssertEqual(registry.descriptor(for: "claude-desktop-code")?.supportedPrecisions, [.application])
        XCTAssertEqual(registry.descriptor(for: "claude-desktop-code")?.supportLevel, .detectedOnly)
        XCTAssertEqual(registry.descriptor(for: "claude-desktop-code")?.bundleIdentifiers, [])
        XCTAssertEqual(registry.descriptor(for: "supacode")?.supportLevel, .experimental)
        XCTAssertTrue(registry.descriptor(for: "supacode")?.isExperimental == true)
        XCTAssertTrue(registry.descriptor(for: "ide-workspace")?.isWorkspaceLevel == true)
        XCTAssertFalse(registry.descriptor(for: "terminal-tty")?.isWorkspaceLevel == true)
    }

    func testPermissionMetadataIsTypedAndNonExecuting() {
        let registry = TerminalRegistry.default

        XCTAssertEqual(registry.descriptor(for: "terminal-tty")?.permissionRequirements, [.automation])
        XCTAssertEqual(registry.descriptor(for: "codex-deeplink")?.permissionRequirements, [.urlScheme])
        XCTAssertEqual(registry.descriptor(for: "ghostty")?.permissionRequirements, [.automation])
        XCTAssertEqual(registry.descriptor(for: "warp")?.permissionRequirements, [.urlScheme, .accessibility])
        XCTAssertEqual(registry.descriptor(for: "tmux")?.permissionRequirements, [.cli, .automation])
        XCTAssertEqual(registry.descriptor(for: "kaku")?.permissionRequirements, [.cli])
        XCTAssertEqual(registry.descriptor(for: "vscode-workspace")?.permissionRequirements, [.cli])
        XCTAssertEqual(registry.descriptor(for: "cursor-workspace")?.permissionRequirements, [.cli])
        XCTAssertEqual(registry.descriptor(for: "jetbrains-workspace")?.permissionRequirements, [.cli])
        XCTAssertEqual(registry.descriptor(for: "cmux")?.permissionRequirements, [.socket])
        XCTAssertEqual(registry.descriptor(for: "workspace")?.permissionRequirements, [.none])
        XCTAssertEqual(registry.descriptor(for: "claude-desktop-code")?.permissionRequirements, [.none])
    }

    func testDescriptorsSupportingPrecisionPreserveRegistryOrder() {
        let exactPaneIds = TerminalRegistry.default.descriptors(supporting: .exactPane).map(\.id)

        XCTAssertEqual(exactPaneIds, [
            "custom-url",
            "codex-deeplink",
            "supacode",
            "cmux",
            "tmux",
            "zellij",
            "wezterm",
            "kaku",
            "otty",
            "iterm"
        ])
    }

    func testDescriptorsSupportingApplicationPrecisionPreserveRegistryOrder() {
        let applicationIds = TerminalRegistry.default.descriptors(supporting: .application).map(\.id)

        XCTAssertEqual(applicationIds, [
            "claude-desktop-code",
            "application"
        ])
    }
}
