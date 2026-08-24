import XCTest
@testable import MyVibeIslandCore

final class OriginalNotchShapeParametersTests: XCTestCase {
    func testResolvesIDAConfirmedPayloadPairsForEachDisplayState() {
        let expected: [(OriginalIslandDisplayState, OriginalNotchShapeParameters)] = [
            (.compact, .init(topCornerRadius: 6, bottomCornerRadius: 14)),
            (.peek, .init(topCornerRadius: 10, bottomCornerRadius: 20)),
            (.expanded, .init(topCornerRadius: 19, bottomCornerRadius: 24)),
        ]
        let resolver = OriginalNotchShapeParametersResolver()

        for (state, parameters) in expected {
            XCTAssertEqual(resolver.resolve(state), parameters)
        }
    }

    func testTopBottomFieldMappingIsRuntimeConfirmed() {
        XCTAssertTrue(OriginalNotchShapeParameters.fieldMappingIsRuntimeConfirmed)
    }
}
