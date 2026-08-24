import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitDiagnosticExportPresenterTests: XCTestCase {
    @MainActor
    func testSelectedDestinationWritesArchiveAndCancelDoesNothing() throws {
        let manifest = DiagnosticBundleManifest(sections: [
            DiagnosticBundleSection(name: "system-info.txt", evidence: .idaString, isRequired: true)
        ])
        let controller = MyVibeIslandAppKitDiagnosticExportController(
            builder: DiagnosticExportBuilder(manifest: manifest),
            collectInputs: {
                [
                    DiagnosticExportSectionInput(
                        name: "system-info.txt",
                        producer: "system",
                        allowedFields: ["appVersion"],
                        forbiddenFields: [],
                        fields: ["appVersion": "1.0"]
                    )
                ]
            }
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandDiagnosticExportPresenter-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("diagnostics.zip")
        let presenter = MyVibeIslandAppKitDiagnosticExportPresenter(
            controller: controller,
            selectDestination: { archiveURL }
        )

        XCTAssertEqual(try presenter.export(), archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))

        let cancelled = MyVibeIslandAppKitDiagnosticExportPresenter(
            controller: controller,
            selectDestination: { nil }
        )
        XCTAssertNil(try cancelled.export())
    }
}
