import Foundation
import XCTest

final class OriginalCompactLocalizationResourcesTests: XCTestCase {
    func testSourceResourcesExactlyMatchFrozenEvidence() throws {
        let evidence = try loadEvidence()
        let resourcesURL = packageRoot
            .appendingPathComponent("Sources/MyVibeIslandApp/Resources", isDirectory: true)
        let resourceURLs = try FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        var localeDirectories: [URL] = []
        for url in resourceURLs where url.pathExtension == "lproj" {
            if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                localeDirectories.append(url)
            }
        }
        let actualLocales = Set(localeDirectories.map {
            $0.deletingPathExtension().lastPathComponent
        })

        XCTAssertEqual(Set(evidence.locales.keys), expectedLocales)
        XCTAssertEqual(actualLocales, expectedLocales)

        for locale in expectedLocales.sorted() {
            let expectedValues = try XCTUnwrap(evidence.locales[locale])
            let stringsURL = resourcesURL
                .appendingPathComponent("\(locale).lproj", isDirectory: true)
                .appendingPathComponent("Localizable.strings")
            let actualValues = try loadStrings(at: stringsURL)

            XCTAssertEqual(expectedValues.count, 16, "Unexpected evidence key count for \(locale)")
            XCTAssertEqual(Set(actualValues.keys), Set(expectedValues.keys), "Key mismatch for \(locale)")
            XCTAssertEqual(actualValues, expectedValues, "Value mismatch for \(locale)")
        }
    }

    func testBuiltAppResourceBundleResolvesEveryFrozenLocalization() throws {
        let evidence = try loadEvidence()
        let appBundleURL = Bundle.module.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("my-vibe-island_MyVibeIslandApp.bundle", isDirectory: true)
        let appBundle = try XCTUnwrap(Bundle(url: appBundleURL), "Missing built app resource bundle")
        let builtLocales = Dictionary(uniqueKeysWithValues: appBundle.localizations.map {
            ($0.lowercased(), $0)
        })

        XCTAssertEqual(Set(builtLocales.keys), Set(expectedLocales.map { $0.lowercased() }))

        for locale in expectedLocales.sorted() {
            let expectedValues = try XCTUnwrap(evidence.locales[locale])
            let builtLocale = try XCTUnwrap(
                builtLocales[locale.lowercased()],
                "Missing built locale \(locale)"
            )
            let localePath = try XCTUnwrap(
                appBundle.path(forResource: builtLocale, ofType: "lproj"),
                "Missing built locale \(locale)"
            )
            let localeBundle = try XCTUnwrap(Bundle(path: localePath))

            for key in expectedValues.keys.sorted() {
                XCTAssertEqual(
                    localeBundle.localizedString(forKey: key, value: nil, table: nil),
                    expectedValues[key],
                    "Built localization mismatch for \(locale):\(key)"
                )
            }
        }
    }

    private let expectedLocales: Set<String> = ["en", "fr", "ja", "ko", "zh-Hans"]

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadEvidence() throws -> CompactLocalizationEvidence {
        let url = packageRoot.appendingPathComponent("docs/research/ida-compact-localization.json")
        return try JSONDecoder().decode(
            CompactLocalizationEvidence.self,
            from: Data(contentsOf: url)
        )
    }

    private func loadStrings(at url: URL) throws -> [String: String] {
        let propertyList = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: url),
            format: nil
        )
        return try XCTUnwrap(propertyList as? [String: String], "Invalid strings file at \(url.path)")
    }
}

private struct CompactLocalizationEvidence: Decodable {
    let locales: [String: [String: String]]
}
