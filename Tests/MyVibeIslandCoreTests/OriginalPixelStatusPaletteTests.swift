import Foundation
import XCTest
@testable import MyVibeIslandCore

final class OriginalPixelStatusPaletteTests: XCTestCase {
    func testAllStatusesUseIDAColors() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(fixture.statuses.map(\.raw), OriginalPixelStatusCompact.allCases.map(\.rawValue))
        for row in fixture.statuses {
            let expected = OriginalPixelStatusPalette(
                primary: row.primaryRGB,
                secondary: row.secondaryRGB
            )
            XCTAssertEqual(OriginalPixelStatusPalette.colors(for: row.status), expected, row.name)
        }
    }

    private func loadFixture() throws -> OriginalPixelStatusPaletteFixture {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot
            .appendingPathComponent("docs/research/ida-pixel-status-icon-compact.json")
        return try JSONDecoder().decode(
            OriginalPixelStatusPaletteFixture.self,
            from: Data(contentsOf: fixtureURL)
        )
    }
}

private struct OriginalPixelStatusPaletteFixture: Decodable {
    struct Status: Decodable {
        let raw: Int
        let name: String
        let primaryRGB: OriginalPixelColor
        let secondaryRGB: OriginalPixelColor

        var status: OriginalPixelStatusCompact {
            OriginalPixelStatusCompact(rawValue: raw)!
        }
    }

    let statuses: [Status]
}
