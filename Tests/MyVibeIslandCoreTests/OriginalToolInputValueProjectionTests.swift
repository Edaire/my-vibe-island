import XCTest
@testable import MyVibeIslandCore

final class OriginalToolInputValueProjectionTests: XCTestCase {
    func testProjectsScalarValues() {
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.string("raw text")), "raw text")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.integer(-42)), "-42")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.number(1.0)), "1.0")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.number(1.25)), "1.25")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.bool(true)), "true")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.bool(false)), "false")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.null), "")
    }

    func testProjectsArraysWithExactSeparatorsAndNullPlaceholders() {
        XCTAssertEqual(
            OriginalToolInputValueProjection.resolve(.array([
                .string("first"),
                .null,
                .integer(3),
            ])),
            "first, , 3"
        )
    }

    func testProjectsObjectsInNativeDictionaryIterationOrder() {
        let object: [String: BridgeJSONValue] = [
            "name": .string("island"),
            "count": .integer(2),
            "enabled": .bool(true),
        ]
        let expectedValues = [
            "name": "island",
            "count": "2",
            "enabled": "true",
        ]
        let expected = object.map { key, _ in
            "\(key): \(expectedValues[key]!)"
        }.joined(separator: ", ")

        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.object(object)), expected)
    }

    func testProjectsNestedArraysAndObjectsRecursively() {
        let nestedObject: [String: BridgeJSONValue] = [
            "items": .array([.string("a"), .null, .number(2.5)]),
            "empty": .object([:]),
        ]
        let expectedValues = [
            "items": "a, , 2.5",
            "empty": "",
        ]
        let expected = nestedObject.map { key, _ in
            "\(key): \(expectedValues[key]!)"
        }.joined(separator: ", ")

        XCTAssertEqual(
            OriginalToolInputValueProjection.resolve(.array([
                .object(nestedObject),
                .array([.bool(false), .integer(7)]),
            ])),
            "\(expected), false, 7"
        )
    }

    func testProjectsEmptyContainersAsEmptyStrings() {
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.array([])), "")
        XCTAssertEqual(OriginalToolInputValueProjection.resolve(.object([:])), "")
    }
}
