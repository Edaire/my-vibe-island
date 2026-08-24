import Foundation
import XCTest
@testable import MyVibeIslandCore

final class BridgeRuntimeContractTests: XCTestCase {
    func testOriginalEvidenceBackedProviderSourcesMatchBridgeCLI() {
        XCTAssertEqual(BridgeRuntimeContract.originalProviderSources, [
            "claude",
            "codex",
            "zcode",
            "gemini",
            "antigravity",
            "cursor",
            "trae",
            "droid",
            "qoder",
            "qwen",
            "grok",
            "kimi",
            "kimicode",
            "deepseek",
            "mistralvibe",
            "copilot",
            "codebuddy",
            "workbuddy",
            "kiro",
            "hermes",
        ])
    }

    func testMyDefaultSocketUsesOwnNamespaceAndEnvironmentOverrideNameMatchesOriginal() {
        XCTAssertEqual(BridgeRuntimeContract.socketEnvironmentVariable, "VIBE_ISLAND_SOCKET")
        XCTAssertEqual(
            BridgeRuntimeContract.defaultSocketPath(homeDirectory: URL(fileURLWithPath: "/Users/tester")),
            "/Users/tester/.my-vibe-island/run/my-vibe-island.sock"
        )
    }

    func testRuntimeLayersDescribeEvidenceBackedBridgeBoundaryOnly() {
        XCTAssertEqual(BridgeRuntimeContract.layers.map(\.name), [
            "CLI Entry",
            "Provider Handlers",
            "Input Collectors",
            "Context Enrichment",
            "Normalized Payload",
            "Socket Transport",
        ])
        XCTAssertEqual(BridgeRuntimeContract.layers.last?.evidence, [
            "VIBE_ISLAND_SOCKET",
            "~/.vibe-island/run/vibe-island.sock",
            "fire-and-forget",
            "waitForResponse",
            "ack",
        ])
    }
}
