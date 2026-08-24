import Foundation
@testable import MyVibeIslandCore

enum FixtureLoader {
    enum Error: Swift.Error, Equatable {
        case missingFixture(String)
        case invalidJSONObject(String)
    }

    static func data(_ name: String, extension fileExtension: String = "json") throws -> Data {
        let components = name.split(separator: "/").map(String.init)
        let resourceName = components.last ?? name
        let subdirectory = components.dropLast().joined(separator: "/")
        let resourceURL: URL?
        if subdirectory.isEmpty {
            resourceURL = Bundle.module.url(forResource: resourceName, withExtension: fileExtension)
        } else {
            resourceURL = Bundle.module.url(
                forResource: resourceName,
                withExtension: fileExtension,
                subdirectory: "Fixtures/\(subdirectory)"
            )
        }

        guard let url = resourceURL else {
            throw Error.missingFixture("\(name).\(fileExtension)")
        }

        return try Data(contentsOf: url)
    }

    static func string(_ name: String, extension fileExtension: String = "json") throws -> String {
        String(decoding: try data(name, extension: fileExtension), as: UTF8.self)
    }

    static func bridgePayload(_ name: String) throws -> [String: BridgeJSONValue] {
        let payload = try JSONDecoder().decode(BridgeJSONValue.self, from: data(name))
        guard case let .object(object) = payload else {
            throw Error.invalidJSONObject(name)
        }

        return object
    }
}
