import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionCardHorizontalCompletionAttachmentPlanTests: XCTestCase {
    func testMemberUsesCompletionUnreadDot() {
        let plan = resolve(
            cardID: "card-1",
            unreadCompletedIDs: ["card-1"],
            ageLabel: "2d"
        )

        XCTAssertEqual(plan.kind, .completionUnreadDot)
    }

    func testNonMemberUsesAgeTagWithOriginalLabel() {
        let plan = resolve(
            cardID: "card-1",
            unreadCompletedIDs: ["card-2"],
            ageLabel: "  just now  "
        )

        XCTAssertEqual(plan.kind, .ageTag("  just now  "))
    }

    func testMembershipUsesExactStringSetBehaviorAcrossMultipleIDs() {
        let cases: [(cardID: String, unreadCompletedIDs: Set<String>, expected: OriginalSessionCardHorizontalCompletionAttachmentPlan.AttachmentKind)] = [
            ("card-1", ["card-1", "card-2", "card-3"], .completionUnreadDot),
            ("card-2", ["card-1", "card-2", "card-3"], .completionUnreadDot),
            ("card-3", ["card-1", "card-2", "card-3"], .completionUnreadDot),
            ("card-4", ["card-1", "card-2", "card-3"], .ageTag("age")),
            ("CARD-1", ["card-1", "card-2", "card-3"], .ageTag("age")),
        ]

        for testCase in cases {
            XCTAssertEqual(
                resolve(
                    cardID: testCase.cardID,
                    unreadCompletedIDs: testCase.unreadCompletedIDs,
                    ageLabel: "age"
                ).kind,
                testCase.expected
            )
        }
    }

    func testEmptyCardIDAndEmptySetElementsFollowSetMembership() {
        XCTAssertEqual(
            resolve(cardID: "", unreadCompletedIDs: [""], ageLabel: "age").kind,
            .completionUnreadDot
        )
        XCTAssertEqual(
            resolve(cardID: "", unreadCompletedIDs: [], ageLabel: "age").kind,
            .ageTag("age")
        )
        XCTAssertEqual(
            resolve(cardID: "card", unreadCompletedIDs: [""], ageLabel: "age").kind,
            .ageTag("age")
        )
    }

    func testEmptyAgeLabelIsPreservedForNonMember() {
        XCTAssertEqual(
            resolve(cardID: "card", unreadCompletedIDs: [], ageLabel: "").kind,
            .ageTag("")
        )
    }

    func testInteractionStateAControlsOpacityForCompletionUnreadDot() {
        XCTAssertEqual(
            resolve(
                cardID: "card",
                unreadCompletedIDs: ["card"],
                ageLabel: "age",
                interactionStateA: false
            ).contentOpacity,
            1.0
        )
        XCTAssertEqual(
            resolve(
                cardID: "card",
                unreadCompletedIDs: ["card"],
                ageLabel: "age",
                interactionStateA: true
            ).contentOpacity,
            0.0
        )
    }

    func testInteractionStateAControlsOpacityForAgeTag() {
        XCTAssertEqual(
            resolve(
                cardID: "card",
                unreadCompletedIDs: [],
                ageLabel: "age",
                interactionStateA: false
            ).contentOpacity,
            1.0
        )
        XCTAssertEqual(
            resolve(
                cardID: "card",
                unreadCompletedIDs: [],
                ageLabel: "age",
                interactionStateA: true
            ).contentOpacity,
            0.0
        )
    }

    func testPlanAndKindAreSendable() {
        let plan = resolve(
            cardID: "card",
            unreadCompletedIDs: ["card"],
            ageLabel: "age"
        )

        assertSendable(plan)
        assertSendable(plan.kind)
    }

    func testDeclarationIsModuleInternalWithoutUIImportsOrCodable() throws {
        let declaration = try String(contentsOf: declarationURL, encoding: .utf8)

        XCTAssertFalse(declaration.contains("public "))
        XCTAssertFalse(declaration.contains("import SwiftUI"))
        XCTAssertFalse(declaration.contains("import AppKit"))
        XCTAssertFalse(declaration.contains("Codable"))
    }

    func testAllNewTypesHaveNoOtherProductionConsumers() throws {
        let sourcesURL = packageRootURL.appendingPathComponent("Sources")
        let sourceFiles = try FileManager.default
            .subpathsOfDirectory(atPath: sourcesURL.path)
            .filter { $0.hasSuffix(".swift") }
            .filter { $0 != "MyVibeIslandCore/Runtime/OriginalSessionCardHorizontalCompletionAttachmentPlan.swift" }

        XCTAssertFalse(sourceFiles.isEmpty)
        for file in sourceFiles {
            let source = try String(
                contentsOf: sourcesURL.appendingPathComponent(file),
                encoding: .utf8
            )
            XCTAssertFalse(source.contains("OriginalSessionCardHorizontalCompletionAttachmentPlan"), file)
        }
    }

    private func resolve(
        cardID: String = "card",
        unreadCompletedIDs: Set<String> = [],
        ageLabel: String = "age",
        interactionStateA: Bool = false
    ) -> OriginalSessionCardHorizontalCompletionAttachmentPlan {
        OriginalSessionCardHorizontalCompletionAttachmentPlan.resolve(
            cardID: cardID,
            unreadCompletedIDs: unreadCompletedIDs,
            ageLabel: ageLabel,
            interactionStateA: interactionStateA
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
            .appendingPathComponent("OriginalSessionCardHorizontalCompletionAttachmentPlan.swift")
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
