import Foundation
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandDiagnosticArchiveWriterTests: XCTestCase {
    func testReadyPlanWritesInspectableZipArchive() throws {
        let root = temporaryRoot()
        let archiveURL = root.appendingPathComponent("diagnostics.zip")
        let writer = MyVibeIslandDiagnosticArchiveWriter()
        let plan = DiagnosticExportWritePlan(
            status: .ready,
            entries: [
                DiagnosticExportWriteEntry(
                    sectionName: "system-info.txt",
                    path: "system-info.txt",
                    redactionLevel: .redacted,
                    fields: ["cwd": "/Users/<user>/project", "appVersion": "1.0"]
                )
            ],
            failures: []
        )

        let result = try writer.write(plan: plan, to: archiveURL)

        XCTAssertEqual(result, archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        let extracted = root.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        try runDitto(["-x", "-k", archiveURL.path, extracted.path])
        let sectionURL = extracted.appendingPathComponent("Vibe-Island-Diagnostics/system-info.txt")
        let fields = try JSONDecoder().decode(
            [String: String].self,
            from: Data(contentsOf: sectionURL)
        )
        XCTAssertEqual(fields["cwd"], "/Users/<user>/project")
        XCTAssertEqual(fields["appVersion"], "1.0")
    }

    func testFailedClosedPlanDoesNotCreateArchive() throws {
        let root = temporaryRoot()
        let archiveURL = root.appendingPathComponent("diagnostics.zip")
        let writer = MyVibeIslandDiagnosticArchiveWriter()
        let plan = DiagnosticExportWritePlan(
            status: .failedClosed,
            entries: [],
            failures: [
                DiagnosticExportWriteFailure(
                    sectionName: "system-info.txt",
                    error: .sectionGenerationFailed
                )
            ]
        )

        XCTAssertThrowsError(try writer.write(plan: plan, to: archiveURL)) { error in
            XCTAssertEqual(error as? MyVibeIslandDiagnosticArchiveError, .failedClosed)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: archiveURL.path))
    }

    private func temporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyVibeIslandDiagnosticArchiveWriterTests-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func runDitto(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
