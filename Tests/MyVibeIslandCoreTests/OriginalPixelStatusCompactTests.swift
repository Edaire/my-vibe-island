import XCTest
@testable import MyVibeIslandCore

final class OriginalPixelStatusCompactTests: XCTestCase {
    func testIDAFrameMatrixMatchesPixelSamples() throws {
        let fixture = try JSONDecoder().decode(
            OriginalPixelStatusCompactFixture.self,
            from: try FixtureLoader.data("runtime/original-pixel-status-compact")
        )

        XCTAssertEqual(OriginalPixelStatusCompact.gridWidth, fixture.grid.width)
        XCTAssertEqual(OriginalPixelStatusCompact.gridHeight, fixture.grid.height)
        XCTAssertEqual(OriginalPixelStatusCompact.frameInterval, fixture.frameInterval)
        XCTAssertEqual(
            fixture.evidence.frameIntervalSource,
            "docs/research/island-reference-standard.md#pixel-status-icon"
        )
        XCTAssertEqual(
            fixture.evidence.idaTimer,
            "PixelStatusIcon internal timer rooted at sub_1005364F0"
        )
        XCTAssertEqual(OriginalPixelStatusCompact.allCases.map(\.rawValue), Array(0...8))

        for row in fixture.cases {
            let frame = OriginalPixelStatusCompact.frame(for: row.status.model, at: row.frame)

            XCTAssertEqual(frame.primaryColor, row.primaryColor, row.id)
            XCTAssertEqual(frame.secondaryColor, row.secondaryColor, row.id)
            assertFaceSamples(frame, row: row, fixture: fixture)
            XCTAssertEqual(
                frame.samples.filter { $0.coordinate.x >= 9 },
                row.branchSamples,
                row.id
            )
            XCTAssertEqual(
                frame.samples.filter { $0.color == OriginalPixelColor(red: 0, green: 0, blue: 0) },
                row.blackOverlaySamples ?? [],
                row.id
            )
            XCTAssertEqual(frame.statusFlag, row.statusFlag, row.id)
        }
    }

    func testIDAFrameProgressionsMatchFixture() throws {
        let fixture = try JSONDecoder().decode(
            OriginalPixelStatusCompactFixture.self,
            from: try FixtureLoader.data("runtime/original-pixel-status-compact")
        )

        for row in fixture.progressions {
            let frame = OriginalPixelStatusCompact.frame(for: row.status.model, at: row.frame)
            assertFaceSamples(frame, row: row, fixture: fixture)
            XCTAssertEqual(
                frame.samples.filter { $0.coordinate.x >= 9 },
                row.branchSamples,
                row.id
            )
            XCTAssertEqual(
                frame.samples.filter { $0.color == OriginalPixelColor(red: 0, green: 0, blue: 0) },
                row.blackOverlaySamples ?? [],
                row.id
            )
            XCTAssertEqual(frame.statusFlag, row.statusFlag, row.id)
        }
    }

    private func assertFaceSamples(
        _ frame: OriginalPixelStatusFrame,
        row: OriginalPixelStatusCompactFixture.Row,
        fixture: OriginalPixelStatusCompactFixture
    ) {
        let expected = fixture.faceSamples.secondaryPixels.map {
            OriginalPixelSample(coordinate: $0, color: row.secondaryColor)
        } + (fixture.faceSamples.upperPrimaryPixels + row.lowerSelection).map {
            OriginalPixelSample(coordinate: $0, color: row.primaryColor)
        }
        let actual = frame.samples.filter {
            $0.coordinate.x < 9 && $0.color != OriginalPixelColor(red: 0, green: 0, blue: 0)
        }

        XCTAssertEqual(actual, expected, row.id)
    }
}

private struct OriginalPixelStatusCompactFixture: Codable {
    struct Evidence: Codable {
        let frameIntervalSource: String
        let idaTimer: String
    }

    struct Grid: Codable {
        let width: Int
        let height: Int
    }

    struct FaceSamples: Codable {
        let secondaryPixels: [OriginalPixelCoordinate]
        let upperPrimaryPixels: [OriginalPixelCoordinate]
    }

    struct Row: Codable {
        let id: String
        let status: FixtureStatus
        let frame: Int
        let primaryColor: OriginalPixelColor
        let secondaryColor: OriginalPixelColor
        let lowerSelection: [OriginalPixelCoordinate]
        let branchSamples: [OriginalPixelSample]
        let blackOverlaySamples: [OriginalPixelSample]?
        let statusFlag: OriginalPixelStatusFlag?
    }

    let evidence: Evidence
    let grid: Grid
    let frameInterval: Double
    let faceSamples: FaceSamples
    let cases: [Row]
    let progressions: [Row]
}

private enum FixtureStatus: String, Codable {
    case waitingForInput
    case processing
    case thinking
    case runningTool
    case waitingForApproval
    case question
    case compacting
    case ended
    case unknown

    var model: OriginalPixelStatusCompact {
        switch self {
        case .waitingForInput: .waitingForInput
        case .processing: .processing
        case .thinking: .thinking
        case .runningTool: .runningTool
        case .waitingForApproval: .waitingForApproval
        case .question: .question
        case .compacting: .compacting
        case .ended: .ended
        case .unknown: .unknown
        }
    }
}
