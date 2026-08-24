import AppKit
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalPeekRowViewTests: XCTestCase {
    func testRowStoresOnlyTheNotification() {
        let notification = makeNotification(level: .warning)
        let view = OriginalPeekNotificationRowView(notification: notification)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: view).children.map {
            ($0.label ?? "", $0.value)
        })

        XCTAssertEqual(Set(fields.keys), ["notification"])
        XCTAssertEqual(fields["notification"] as? OriginalPeekNotification, notification)
    }

    func testProviderAndLevelAppearanceMatrix() {
        let providerAppearances: [(OriginalPeekProvider, Double, Double, Double)] = [
            (.anthropic, 0.80, 0.61, 0.48),
            (.openai, 0.06, 0.64, 0.50),
            (.google, 0.26, 0.52, 0.96),
            (.zhipu, 0.20, 0.60, 0.90),
            (.kimi, 0.10, 0.37, 1.00),
        ]
        let symbols: [OriginalPeekLevel: String] = [
            .info: "checkmark.circle.fill",
            .warning: "exclamationmark.triangle.fill",
            .critical: "exclamationmark.octagon.fill",
        ]
        for (provider, red, green, blue) in providerAppearances {
            for level in OriginalPeekLevel.allCases {
                let appearance = OriginalPeekNotificationRowAppearance.resolve(
                    makeNotification(provider: provider, level: level)
                )
                XCTAssertEqual(appearance.symbol, symbols[level])
                XCTAssertEqual(appearance.red, red, "provider=\(provider) level=\(level)")
                XCTAssertEqual(appearance.green, green, "provider=\(provider) level=\(level)")
                XCTAssertEqual(appearance.blue, blue, "provider=\(provider) level=\(level)")
                XCTAssertEqual(appearance.opacity, 1, "provider=\(provider) level=\(level)")
            }
        }

        let nilProviderAppearances: [(OriginalPeekLevel, OriginalPeekNotificationRowAppearance)] = [
            (.info, .init(symbol: "checkmark.circle.fill", red: 1, green: 1, blue: 1, opacity: 0.55)),
            (.warning, .init(symbol: "exclamationmark.triangle.fill", red: 0.98, green: 0.57, blue: 0.24, opacity: 1)),
            (.critical, .init(symbol: "exclamationmark.octagon.fill", red: 0.98, green: 0.45, blue: 0.09, opacity: 1)),
        ]
        for (level, expected) in nilProviderAppearances {
            XCTAssertEqual(
                OriginalPeekNotificationRowAppearance.resolve(makeNotification(provider: nil, level: level)),
                expected
            )
        }
    }

    func testProductionSourceLocksRowStructureAndExcludesUsageLimit() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let requiredInOrder = [
            "public struct OriginalPeekNotificationRowView: View {",
            "public let notification: OriginalPeekNotification",
            "HStack(alignment: .center, spacing: 6)",
            "VStack(alignment: .leading, spacing: 0)",
            "Text(notification.title)",
            ".font(.system(size: 10.5, weight: .semibold))",
            ".foregroundStyle(Color.white.opacity(0.9))",
            ".lineLimit(1)",
            "Text(notification.detail)",
            ".font(.system(size: 9.5))",
            ".foregroundStyle(Color.white.opacity(0.48))",
            ".lineLimit(1)",
            ".frame(height: 30)",
            ".padding(.horizontal, 4)",
        ]

        var searchStart = source.startIndex
        for required in requiredInOrder {
            let range = try XCTUnwrap(
                source.range(of: required, range: searchStart..<source.endIndex),
                "Missing or out-of-order source contract: \(required)"
            )
            searchStart = range.upperBound
        }
        XCTAssertFalse(source.contains("usageLimit"))

        XCTAssertEqual(source.components(separatedBy: ".font(").count - 1, 3)
        XCTAssertEqual(source.components(separatedBy: ".foregroundStyle(").count - 1, 3)
        XCTAssertEqual(source.components(separatedBy: ".lineLimit(1)").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: ".frame(").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: ".padding(").count - 1, 1)
    }

    func testRealBodiesContainExpectedPeekRowChildren() {
        let notification = makeNotification(provider: .openai, level: .warning)
        let supplemental = OriginalPeekSupplementalView(state: .peek(notification, kind: .taskComplete))
        let supplementalDescendants = mirrorDescendants(of: supplemental.body)
        let row = OriginalPeekNotificationRowView(notification: notification)
        let rowDescendants = mirrorDescendants(of: row.body)

        XCTAssertEqual(countType(named: "OriginalPeekNotificationRowView", in: supplementalDescendants), 1)
        XCTAssertEqual(countType(named: "Image", in: rowDescendants), 1)
        XCTAssertEqual(countType(named: "Text", in: rowDescendants), 2)
        XCTAssertTrue(rowDescendants.contains { String(describing: $0).contains(notification.title) })
        XCTAssertTrue(rowDescendants.contains { String(describing: $0).contains(notification.detail) })
    }

    func testSupplementalSourceOnlyAddsRowForPeekAndCallerPadding() throws {
        let source = try String(contentsOf: supplementalSourceURL, encoding: .utf8)
        let requiredInOrder = [
            "case .row(let notification):",
            "OriginalPeekNotificationRowView(notification: notification)",
            ".padding(.horizontal, 4)",
            ".padding(.bottom, 5)",
            "case .empty:",
        ]
        var searchStart = source.startIndex
        for required in requiredInOrder {
            let range = try XCTUnwrap(
                source.range(of: required, range: searchStart..<source.endIndex),
                "Missing or out-of-order supplemental source: \(required)"
            )
            searchStart = range.upperBound
        }
        XCTAssertEqual(source.components(separatedBy: ".padding(").count - 1, 2)
        XCTAssertFalse(source.contains("usageLimit"))
    }

    private var productionSourceURL: URL {
        repositoryRoot.appendingPathComponent(
            "Sources/MyVibeIslandApp/OriginalPeekNotificationRowView.swift"
        )
    }

    private var supplementalSourceURL: URL {
        repositoryRoot.appendingPathComponent(
            "Sources/MyVibeIslandApp/OriginalPeekSupplementalView.swift"
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeNotification(
        provider: OriginalPeekProvider? = .anthropic,
        level: OriginalPeekLevel = .info
    ) -> OriginalPeekNotification {
        OriginalPeekNotification(
            id: "n-1",
            title: "Done",
            detail: "Task completed",
            provider: provider,
            level: level
        )
    }

    private func mirrorDescendants(of value: Any) -> [Any] {
        [value] + Mirror(reflecting: value).children.flatMap { mirrorDescendants(of: $0.value) }
    }

    private func countType(named name: String, in values: [Any]) -> Int {
        values.filter {
            String(reflecting: type(of: $0)).split(separator: ".").last.map(String.init) == name
        }.count
    }
}
