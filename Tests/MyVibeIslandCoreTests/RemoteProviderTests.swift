import XCTest
@testable import MyVibeIslandCore

final class RemoteProviderTests: XCTestCase {
    func testRemoteProviderMarkerMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteProviderMarkerFixture.self,
            from: try FixtureLoader.data("remote/provider-marker")
        )
        let encoded = try JSONEncoder().encode(RemoteProvider())

        let actual = RemoteProviderMarkerFixture(
            encodedJSONObject: try JSONDecoder().decode([String: String].self, from: encoded),
            encodedByteCount: encoded.count,
            isEmptyMarker: encoded == Data("{}".utf8)
        )

        XCTAssertEqual(actual, expected)
    }

    func testRemoteProviderIsEmptyMarkerThatRoundTripsThroughJSON() throws {
        let provider = RemoteProvider()

        let data = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(RemoteProvider.self, from: data)

        XCTAssertEqual(decoded, provider)
        XCTAssertEqual(String(data: data, encoding: .utf8), "{}")
    }

    private struct RemoteProviderMarkerFixture: Codable, Equatable {
        let encodedJSONObject: [String: String]
        let encodedByteCount: Int
        let isEmptyMarker: Bool
    }
}
