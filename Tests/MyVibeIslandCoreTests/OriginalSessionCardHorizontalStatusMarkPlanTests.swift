import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalSessionCardHorizontalStatusMarkPlanTests: XCTestCase {
    func testObservedStatusMarkPlan() {
        let plan = OriginalSessionCardHorizontalStatusMarkPlan.original

        XCTAssertEqual(plan.foreground, .white(opacity: 0.20))
        XCTAssertEqual(plan.width, 6)
        XCTAssertEqual(plan.height, 6)
        XCTAssertEqual(plan.alignment, .center)
        assertSendable(plan)
    }

    func testDeclarationIsModuleInternalWithoutUIOrCodable() throws {
        let declaration = try String(contentsOf: declarationURL, encoding: .utf8)

        XCTAssertFalse(declaration.contains("public "))
        XCTAssertFalse(declaration.contains("import SwiftUI"))
        XCTAssertFalse(declaration.contains("import AppKit"))
        XCTAssertFalse(declaration.contains("Codable"))
        XCTAssertFalse(declaration.contains("Shape"))
        XCTAssertFalse(declaration.contains("State"))
        XCTAssertFalse(declaration.contains("Source"))
        XCTAssertFalse(declaration.contains("Renderer"))
    }

    func testSourcesContainNoProductionConsumer() throws {
        let sourcesURL = packageRootURL.appendingPathComponent("Sources")
        let sourceFiles = try FileManager.default
            .subpathsOfDirectory(atPath: sourcesURL.path)
            .filter { $0.hasSuffix(".swift") }
            .filter {
                $0 != "MyVibeIslandCore/Runtime/OriginalSessionCardHorizontalStatusMarkPlan.swift"
            }

        XCTAssertFalse(sourceFiles.isEmpty)
        for file in sourceFiles {
            let source = try String(
                contentsOf: sourcesURL.appendingPathComponent(file),
                encoding: .utf8
            )
            XCTAssertFalse(source.contains("OriginalSessionCardHorizontalStatusMarkPlan"), file)
        }
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
            .appendingPathComponent("OriginalSessionCardHorizontalStatusMarkPlan.swift")
    }

    private func assertSendable<T: Sendable>(_: T) {}
}
