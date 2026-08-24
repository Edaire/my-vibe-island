import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionCardHorizontalIdentityTagPlanTests: XCTestCase {
    func testRemoteGateFalseOmitsRemoteTag() {
        XCTAssertEqual(
            resolve(remoteGate: false, remoteProducer: "Codex").tags,
            []
        )
    }

    func testRemoteGateTrueUsesProducerWithExactPrefix() {
        XCTAssertEqual(
            resolve(remoteGate: true, remoteProducer: "Codex").tags,
            [.remote("📡 Codex")]
        )
    }

    func testRemoteProducerNilUsesExactRemoteFallback() {
        XCTAssertEqual(
            resolve(remoteGate: true, remoteProducer: nil).tags,
            [.remote("📡 Remote")]
        )
    }

    func testRemoteProducerEmptyIsPreservedAfterPrefix() {
        XCTAssertEqual(
            resolve(remoteGate: true, remoteProducer: "").tags,
            [.remote("📡 ")]
        )
    }

    func testRemoteProducerNonemptyValueIsPreservedWithoutTrimming() {
        XCTAssertEqual(
            resolve(remoteGate: true, remoteProducer: "  Codex  ").tags,
            [.remote("📡   Codex  ")]
        )
    }

    func testTerminalGateFalseOmitsTerminalTag() {
        XCTAssertEqual(
            resolve(terminalLabel: "Terminal B", terminalGate: false).tags,
            []
        )
    }

    func testTerminalGateTrueOmitsEqualBaselineLabel() {
        XCTAssertEqual(
            resolve(terminalLabel: "Terminal A", terminalGate: true, baselineLabel: "Terminal A").tags,
            []
        )
    }

    func testTerminalGateTrueAddsDifferentTerminalLabel() {
        XCTAssertEqual(
            resolve(terminalLabel: "Terminal B", terminalGate: true, baselineLabel: "Terminal A").tags,
            [.terminal("Terminal B")]
        )
    }

    func testDifferentEmptyTerminalLabelIsStillAdded() {
        XCTAssertEqual(
            resolve(terminalLabel: "", terminalGate: true, baselineLabel: "Terminal A").tags,
            [.terminal("")]
        )
    }

    func testBothTagsAreOrderedRemoteThenTerminal() {
        XCTAssertEqual(
            resolve(
                remoteGate: true,
                remoteProducer: "Remote Agent",
                terminalLabel: "Terminal B",
                terminalGate: true,
                baselineLabel: "Terminal A"
            ).tags,
            [.remote("📡 Remote Agent"), .terminal("Terminal B")]
        )
    }

    func testPlanAndTagAreSendable() {
        let plan = resolve(
            remoteGate: true,
            remoteProducer: "Remote",
            terminalLabel: "Other",
            terminalGate: true,
            baselineLabel: "Baseline"
        )

        assertSendable(plan)
        for tag in plan.tags {
            assertSendable(tag)
        }
    }

    func testDeclarationHasNoPublicUIImportsOrCodable() throws {
        let declaration = try String(contentsOf: declarationURL, encoding: .utf8)

        XCTAssertFalse(declaration.contains("public "))
        XCTAssertFalse(declaration.contains("import SwiftUI"))
        XCTAssertFalse(declaration.contains("import AppKit"))
        XCTAssertFalse(declaration.contains("Codable"))
        XCTAssertFalse(declaration.contains("TagPill"))
        XCTAssertFalse(declaration.contains("hover"))
    }

    func testSourcesContainNoProductionConsumer() throws {
        let sourcesURL = packageRootURL.appendingPathComponent("Sources")
        let sourceFiles = try FileManager.default
            .subpathsOfDirectory(atPath: sourcesURL.path)
            .filter { $0.hasSuffix(".swift") }
            .filter {
                $0 != "MyVibeIslandCore/Runtime/OriginalSessionCardHorizontalIdentityTagPlan.swift"
            }

        XCTAssertFalse(sourceFiles.isEmpty)
        for file in sourceFiles {
            let source = try String(
                contentsOf: sourcesURL.appendingPathComponent(file),
                encoding: .utf8
            )
            XCTAssertFalse(source.contains("OriginalSessionCardHorizontalIdentityTagPlan"), file)
        }
    }

    private func resolve(
        remoteGate: Bool = false,
        remoteProducer: String? = nil,
        terminalLabel: String = "Terminal A",
        terminalGate: Bool = false,
        baselineLabel: String = "Terminal A"
    ) -> OriginalSessionCardHorizontalIdentityTagPlan {
        OriginalSessionCardHorizontalIdentityTagPlan.resolve(
            remoteGate: remoteGate,
            remoteProducer: remoteProducer,
            terminalLabel: terminalLabel,
            terminalGate: terminalGate,
            baselineLabel: baselineLabel
        )
    }

    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var declarationURL: URL {
        packageRootURL
            .appendingPathComponent("Sources/MyVibeIslandCore/Runtime")
            .appendingPathComponent("OriginalSessionCardHorizontalIdentityTagPlan.swift")
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
