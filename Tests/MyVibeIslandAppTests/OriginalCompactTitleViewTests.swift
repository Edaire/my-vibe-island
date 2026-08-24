import Foundation
import SwiftUI
import XCTest
@testable import MyVibeIslandApp
import MyVibeIslandCore

@MainActor
final class OriginalCompactTitleViewTests: XCTestCase {
    func testViewStoresExactlyPlanAndStyle() {
        let plan = OriginalCompactTitlePlan(content: .verbatim("Frozen title"))
        let style = makeStyle()
        let view = OriginalCompactTitleView(plan: plan, style: style)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: view).children.map {
            ($0.label ?? "", $0.value)
        })

        XCTAssertEqual(Set(fields.keys), ["plan", "style"])
        XCTAssertEqual(fields["plan"] as? OriginalCompactTitlePlan, plan)
        XCTAssertEqual(fields["style"] as? OriginalCompactBaseLayoutPlan.TitleStyle, style)
    }

    func testVerbatimContentUsesExactString() {
        let plan = OriginalCompactTitlePlan(content: .verbatim("Exact %@ title"))

        XCTAssertEqual(OriginalCompactTitleView.concreteTitle(for: plan), "Exact %@ title")
    }

    func testEveryAcceptedLocaleLookupResolvesFromAppModuleResources() throws {
        let expected = [
            "en": "Running",
            "fr": "Exécution",
            "ja": "実行中",
            "ko": "실행 중",
            "zh-Hans": "运行中",
        ]

        for locale in expected.keys.sorted() {
            let bundle = try localizedAppBundle(locale: locale)
            XCTAssertEqual(
                bundle.localizedString(forKey: "tool.running", value: "Running", table: nil),
                expected[locale],
                "Locale lookup mismatch for \(locale)"
            )
        }
    }

    func testLocalizedAllowTitleFormatsArgument() {
        let plan = OriginalCompactTitlePlan(
            content: .localized(
                key: "tool.allowPrefix",
                englishFallback: "Allow %@",
                formatArgument: "Terminal"
            )
        )

        XCTAssertTrue([
            "Allow Terminal",
            "Autoriser Terminal",
            "Terminal を許可",
            "Terminal 허용",
            "允许 Terminal",
        ].contains(OriginalCompactTitleView.concreteTitle(for: plan)))
    }

    func testLocalizedThinkingTitleFormatsArgument() {
        let plan = OriginalCompactTitlePlan(
            content: .localized(
                key: "tool.thinkingDetail",
                englishFallback: "Thinking: %@",
                formatArgument: "indexing"
            )
        )

        XCTAssertTrue([
            "Thinking: indexing",
            "Réflexion : indexing",
            "思考中：indexing",
            "생각 중: indexing",
        ].contains(OriginalCompactTitleView.concreteTitle(for: plan)))
    }

    func testPhysicalTransformRunsAfterLocalizationAndFormatting() {
        let plan = OriginalCompactTitlePlan(
            content: .localized(
                key: "test.missing.physicalTitle",
                englishFallback: "Localized %@",
                formatArgument: "abcdefghijklmnopqrstuvwxyz"
            ),
            transform: .physicalCompact
        )

        XCTAssertEqual(OriginalCompactTitleView.concreteTitle(for: plan), "Localized abcdefghijkl...")
    }

    func testProductionSourceLocksExactLocalizationAndTypographyContract() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            "public struct OriginalCompactTitleView: View",
            "public let plan: OriginalCompactTitlePlan",
            "public let style: OriginalCompactBaseLayoutPlan.TitleStyle",
            "NSLocalizedString(",
            "tableName: nil",
            "bundle: .module",
            "value: englishFallback",
            "comment: \"\"",
            "String(format: localized, locale: nil, arguments: [formatArgument])",
            "plan.transform.apply(to: concrete)",
            "Text(title)",
            ".font(.system(size: style.fontSize, weight: .medium, design: .monospaced))",
            ".foregroundStyle(Color.white.opacity(style.foregroundOpacity))",
            "if let lineLimit = style.lineLimit",
            "if style.truncationMode == .tail",
            ".lineLimit(lineLimit)",
            ".truncationMode(.tail)",
        ] {
            XCTAssertTrue(source.contains(required), "Missing production source: \(required)")
        }
    }

    func testProductionSourceHasNoLayoutOrForbiddenMechanisms() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for forbidden in [
            "import AppKit",
            "CALayer",
            "NSView",
            "NSLocalizedString(\"",
            "Image(",
            "systemName",
            "GeometryReader",
            ".animation(",
            "withAnimation",
            ".padding(",
            ".frame(",
            ".fixedSize(",
            ".layoutPriority(",
            ".offset(",
            ".position(",
            ".symbolEffect(",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }

        for forbiddenCopy in [
            "Vibe Island",
            "Claude",
            "Codex",
            "Working...",
            "Thinking...",
        ] {
            XCTAssertFalse(source.contains(forbiddenCopy), "Forbidden production copy: \(forbiddenCopy)")
        }
    }

    private func makeStyle() -> OriginalCompactBaseLayoutPlan.TitleStyle {
        OriginalCompactBaseLayoutPlan.TitleStyle(
            fontSize: 10,
            fontWeight: .medium,
            fontDesign: .monospaced,
            foregroundOpacity: 0.9,
            lineLimit: 1,
            truncationMode: .tail
        )
    }

    private func localizedAppBundle(locale: String) throws -> Bundle {
        let appBundleURL = Bundle.module.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("my-vibe-island_MyVibeIslandApp.bundle", isDirectory: true)
        let appBundle = try XCTUnwrap(Bundle(url: appBundleURL))
        let localization = try XCTUnwrap(
            appBundle.localizations.first { $0.caseInsensitiveCompare(locale) == .orderedSame }
        )
        let path = try XCTUnwrap(appBundle.path(forResource: localization, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalCompactTitleView.swift")
    }
}
