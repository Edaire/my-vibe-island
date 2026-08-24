import XCTest
@testable import MyVibeIslandCore

final class BridgeJSONValueIntegerPreservationTests: XCTestCase {
    func testDecodesTopLevelIntegerAsInteger() throws {
        XCTAssertEqual(try decode("1"), .integer(1))
    }

    func testDecodesIntegralDecimalAsInteger() throws {
        XCTAssertEqual(try decode("1.0"), .integer(1))
    }

    func testDecodesIntegralExponentAsInteger() throws {
        XCTAssertEqual(try decode("1e0"), .integer(1))
    }

    func testDecodesNonIntegralDoubleAsNumber() throws {
        XCTAssertEqual(try decode("1.5"), .number(1.5))
    }

    func testDoesNotMisclassifyBoolAsNumber() throws {
        guard case .bool(true) = try decode("true") else {
            return XCTFail("Expected true to decode as a bool")
        }
    }

    func testDoesNotMisclassifyStringAsNumber() throws {
        XCTAssertEqual(try decode(#""1""#), .string("1"))
    }

    func testPreservesIntegersInNestedArraysAndObjects() throws {
        let value = try decode(#"{"array":[1,1.5],"object":{"integer":2}}"#)

        XCTAssertEqual(value, .object([
            "array": .array([.integer(1), .number(1.5)]),
            "object": .object(["integer": .integer(2)]),
        ]))
    }

    func testEncodesIntegerWithIntEncoder() throws {
        XCTAssertEqual(String(decoding: try JSONEncoder().encode(BridgeJSONValue.integer(1)), as: UTF8.self), "1")
    }

    func testEncodesNonIntegralDoubleAsNumber() throws {
        XCTAssertEqual(String(decoding: try JSONEncoder().encode(BridgeJSONValue.number(1.5)), as: UTF8.self), "1.5")
    }

    private func decode(_ json: String) throws -> BridgeJSONValue {
        try JSONDecoder().decode(BridgeJSONValue.self, from: Data(json.utf8))
    }
}
