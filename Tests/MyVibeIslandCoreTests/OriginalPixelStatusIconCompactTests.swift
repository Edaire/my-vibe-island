import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalPixelStatusIconCompactTests: XCTestCase {
    func testIDAFixtureMatchesEveryStaticFrame() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(OriginalPixelStatusIconCompact.gridWidth, fixture.grid.width)
        XCTAssertEqual(OriginalPixelStatusIconCompact.gridHeight, fixture.grid.height)
        XCTAssertEqual(OriginalPixelStatusIconCompact.frameWidth, fixture.frame.width)
        XCTAssertEqual(OriginalPixelStatusIconCompact.frameHeight, fixture.frame.height)
        XCTAssertFalse(fixture.hasPhase)
        XCTAssertFalse(fixture.hasTimer)
        XCTAssertFalse(fixture.hasAnimation)
        XCTAssertEqual(fixture.storedFieldCount, 1)
        XCTAssertEqual(fixture.statuses.map(\.raw), OriginalPixelStatusCompact.allCases.map(\.rawValue))

        for row in fixture.statuses {
            let renderer = OriginalPixelStatusIconCompact(status: row.status)
            let frame = renderer.frame
            let primaryColor = row.primaryRGB

            XCTAssertEqual(frame.primaryColor, primaryColor, row.name)
            XCTAssertEqual(
                frame.blackSamples,
                fixture.blackSamples.map { OriginalPixelSample(coordinate: $0, color: .black) },
                row.name
            )
            XCTAssertEqual(
                frame.primarySamples,
                fixture.primarySamples.map { OriginalPixelSample(coordinate: $0, color: primaryColor) },
                row.name
            )
            XCTAssertEqual(renderer.frame, frame, row.name)
        }
    }

    func testIDAFixtureDrivesEveryPixelRectCase() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(fixture.pixelRectCases.count, 5)
        for row in fixture.pixelRectCases {
            XCTAssertEqual(
                OriginalPixelStatusIconCompact.pixelRect(
                    for: row.coordinate,
                    canvasWidth: row.canvas[0],
                    canvasHeight: row.canvas[1]
                ),
                row.expectedRect,
                row.id
            )
        }
    }

    func testRendererHasOneStoredFieldAndNoForbiddenProductionTokens() throws {
        let fixture = try loadFixture()
        let renderer = OriginalPixelStatusIconCompact(status: .waitingForInput)
        let storedFields = Array(Mirror(reflecting: renderer).children)

        XCTAssertEqual(fixture.storedFieldCount, 1)
        XCTAssertEqual(storedFields.count, fixture.storedFieldCount)
        XCTAssertEqual(storedFields.compactMap(\.label), ["status"])
        XCTAssertEqual(
            MemoryLayout<OriginalPixelStatusIconCompact>.size,
            MemoryLayout<OriginalPixelStatusCompact>.size
        )
        XCTAssertEqual(
            MemoryLayout<OriginalPixelStatusIconCompact>.stride,
            MemoryLayout<OriginalPixelStatusCompact>.stride
        )
        XCTAssertEqual(
            MemoryLayout<OriginalPixelStatusIconCompact>.alignment,
            MemoryLayout<OriginalPixelStatusCompact>.alignment
        )

        let productionTokens = try loadProductionTokens()
        for forbiddenToken in fixture.forbiddenProductionTokens {
            XCTAssertFalse(
                productionTokens.contains(forbiddenToken),
                "Forbidden production token: \(forbiddenToken)"
            )
        }
    }

    private func loadFixture() throws -> OriginalPixelStatusIconCompactFixture {
        let fixtureURL = repositoryRoot
            .appendingPathComponent("docs/research/ida-pixel-status-icon-compact.json")
        return try JSONDecoder().decode(
            OriginalPixelStatusIconCompactFixture.self,
            from: Data(contentsOf: fixtureURL)
        )
    }

    private func loadProductionTokens() throws -> Set<String> {
        let sourceURL = repositoryRoot
            .appendingPathComponent("Sources/MyVibeIslandCore/Runtime/OriginalPixelStatusIconCompact.swift")
        let source = String(decoding: try Data(contentsOf: sourceURL), as: UTF8.self)
        return Set(source.split { character in
            !character.isLetter && !character.isNumber && character != "_"
        }.map(String.init))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct OriginalPixelStatusIconCompactFixture: Decodable {
    struct Grid: Decodable {
        let width: Int
        let height: Int
    }

    struct Frame: Decodable {
        let width: Int
        let height: Int
    }

    struct Status: Decodable {
        let raw: Int
        let name: String
        let primaryRGB: OriginalPixelColor

        var status: OriginalPixelStatusCompact {
            OriginalPixelStatusCompact(rawValue: raw)!
        }
    }

    struct PixelRectCase: Decodable {
        let id: String
        let canvas: [Double]
        let coordinate: OriginalPixelCoordinate
        let expected: [Double]

        var expectedRect: OriginalPixelRect {
            OriginalPixelRect(
                x: expected[0],
                y: expected[1],
                width: expected[2],
                height: expected[3]
            )
        }
    }

    let grid: Grid
    let frame: Frame
    let pixelRectCases: [PixelRectCase]
    let blackSamples: [OriginalPixelCoordinate]
    let primarySamples: [OriginalPixelCoordinate]
    let statuses: [Status]
    let storedFieldCount: Int
    let forbiddenProductionTokens: [String]
    let hasPhase: Bool
    let hasTimer: Bool
    let hasAnimation: Bool
}

private extension OriginalPixelColor {
    static let black = OriginalPixelColor(red: 0, green: 0, blue: 0)
}
