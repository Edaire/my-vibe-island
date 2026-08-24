import XCTest
@testable import MyVibeIslandCore

final class DiagnosticBundleErrorTests: XCTestCase {
    func testDiagnosticBundleErrorMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            DiagnosticBundleErrorMatrixFixture.self,
            from: try FixtureLoader.data("diagnostics/bundle-error-matrix")
        )
        let errors = DiagnosticBundle.DiagnosticError.allFixtureCases

        XCTAssertEqual(errors, expected.errors)
        XCTAssertEqual(errors.map(\.rawValue), expected.rawValues)
    }

    func testDiagnosticBundleErrorRoundTripsKnownLocalFailureCases() throws {
        let errors: [DiagnosticBundle.DiagnosticError] = [
            .cannotCreateArchive,
            .sectionGenerationFailed,
            .redactionFailed,
            .permissionDenied,
            .crashReportCollectionFailed,
            .hangSampleReadFailed
        ]

        let data = try JSONEncoder().encode(errors)
        let decoded = try JSONDecoder().decode([DiagnosticBundle.DiagnosticError].self, from: data)

        XCTAssertEqual(decoded, errors)
        XCTAssertEqual(DiagnosticBundle.DiagnosticError.redactionFailed.rawValue, "redactionFailed")
    }

    private struct DiagnosticBundleErrorMatrixFixture: Codable, Equatable {
        let errors: [DiagnosticBundle.DiagnosticError]
        let rawValues: [String]
    }
}

private extension DiagnosticBundle.DiagnosticError {
    static let allFixtureCases: [DiagnosticBundle.DiagnosticError] = [
        .cannotCreateArchive,
        .sectionGenerationFailed,
        .redactionFailed,
        .permissionDenied,
        .crashReportCollectionFailed,
        .hangSampleReadFailed
    ]
}
