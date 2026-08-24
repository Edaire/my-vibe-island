import Foundation

enum SetupFixtureLoader {
    enum Error: Swift.Error, Equatable {
        case missingFixture(String)
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
}
