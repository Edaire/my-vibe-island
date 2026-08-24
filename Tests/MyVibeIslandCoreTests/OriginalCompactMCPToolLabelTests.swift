import XCTest
@testable import MyVibeIslandCore

final class OriginalCompactMCPToolLabelTests: XCTestCase {
    func testOrdinaryMCPToolUsesServerAndTool() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__filesystem__read_file"),
            "filesystem: read_file"
        )
    }

    func testPluginServerUsesPluginName() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__plugin_server__run"),
            "server: run"
        )
    }

    func testPluginServerUsesLastUnderscoreSeparatedSegment() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__plugin_alpha_beta__run"),
            "beta: run"
        )
    }

    func testAdditionalOuterSegmentsAreIgnored() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__server__tool__ignored"),
            "server: tool"
        )
    }

    func testNonMCPToolReturnsNil() {
        XCTAssertNil(OriginalCompactMCPToolLabel.resolve("server__tool"))
    }

    func testBarePrefixFallsBackToOriginalInput() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__"),
            "MCP: mcp__"
        )
    }

    func testMissingServerFallsBackToOriginalInput() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp____tool"),
            "MCP: mcp____tool"
        )
    }

    func testConsecutiveEmptySegmentsAreIgnored() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__server____tool"),
            "server: tool"
        )
    }

    func testPrefixMatchingIsCaseSensitive() {
        XCTAssertNil(OriginalCompactMCPToolLabel.resolve("MCP__server__tool"))
    }

    func testPluginPrefixMatchingIsCaseSensitive() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__Plugin_server__tool"),
            "Plugin_server: tool"
        )
    }

    func testWhitespaceIsNotNormalized() {
        XCTAssertEqual(
            OriginalCompactMCPToolLabel.resolve("mcp__ server __ tool "),
            " server :  tool "
        )
    }
}
