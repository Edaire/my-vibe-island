import XCTest
@testable import MyVibeIslandCore

final class AgentRegistryTests: XCTestCase {
    func testDefaultRegistryMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            [AgentDescriptor].self,
            from: try FixtureLoader.data("agents/default-agent-registry")
        )

        XCTAssertEqual(AgentRegistry.default.descriptors, expected)
    }

    func testDefaultRegistryContainsSupportedNonCommercialAgents() {
        let registry = AgentRegistry.default
        let ids = registry.descriptors.map(\.id)

        XCTAssertEqual(ids, [
            "claude",
            "codex",
            "opencode",
            "gemini",
            "cursor",
            "kimi",
            "claude-desktop",
            "codex-desktop",
            "qwen",
            "qoder",
            "factory",
            "codebuddy",
            "hermes"
        ])
        XCTAssertEqual(registry.descriptor(for: "claude")?.supportLevel, .supported)
        XCTAssertEqual(registry.descriptor(for: "codex")?.supportLevel, .supported)
        XCTAssertEqual(registry.descriptor(for: "opencode")?.supportLevel, .supported)
        XCTAssertEqual(registry.descriptor(for: "kimi")?.supportLevel, .experimental)
        XCTAssertEqual(registry.descriptor(for: "claude-desktop")?.displayName, "Claude Desktop Code")
        XCTAssertEqual(registry.descriptor(for: "claude-desktop")?.supportLevel, .experimental)
        XCTAssertEqual(registry.descriptor(for: "codex-desktop")?.displayName, "Codex Desktop App")
        XCTAssertEqual(registry.descriptor(for: "codex-desktop")?.supportLevel, .experimental)
        XCTAssertNil(registry.descriptor(for: "license"))
    }

    func testSupportLevelsDecodeFromDocumentationNames() throws {
        let decoded = try JSONDecoder().decode(AgentSupportLevel.self, from: Data(#""detectedOnly""#.utf8))

        XCTAssertEqual(decoded, .detectedOnly)
    }
}
