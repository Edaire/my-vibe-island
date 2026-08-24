import Foundation

struct MyVibeIslandResourceResolver {
    private let mainBundle: Bundle
    private let moduleBundle: Bundle

    init(mainBundle: Bundle = .main, moduleBundle: Bundle = .module) {
        self.mainBundle = mainBundle
        self.moduleBundle = moduleBundle
    }

    func url(
        forResource name: String,
        withExtension fileExtension: String? = nil,
        subdirectory: String? = nil
    ) -> URL? {
        mainBundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) ?? moduleBundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        )
    }
}
