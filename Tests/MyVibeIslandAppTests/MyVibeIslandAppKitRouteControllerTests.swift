import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitRouteControllerTests: XCTestCase {
    @MainActor
    func testRouteControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RouteControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/route-controller-matrix")
        )

        var events: [String] = []
        let controller = MyVibeIslandAppKitRouteController(
            activateApplication: {
                events.append("activate")
            },
            showWindow: { window in
                events.append("window:\(window)")
            },
            quitApplication: {
                events.append("quit")
            }
        )

        events.removeAll()
        controller.showIsland()
        let showIsland = RouteControllerMatrixRow(id: "show-island", events: events)

        events.removeAll()
        controller.openSettings(SettingsDeepLink(section: .integrations, rowId: "codex"))
        let settingsDeepLink = RouteControllerMatrixRow(id: "settings-deep-link", events: events)

        events.removeAll()
        controller.openSettings(nil)
        let settingsDefault = RouteControllerMatrixRow(id: "settings-default", events: events)

        events.removeAll()
        controller.showOnboarding()
        let onboarding = RouteControllerMatrixRow(id: "onboarding", events: events)

        events.removeAll()
        controller.quit()
        let quit = RouteControllerMatrixRow(id: "quit", events: events)

        let rows = [
            showIsland,
            settingsDeepLink,
            settingsDefault,
            onboarding,
            quit
        ]

        XCTAssertEqual(RouteControllerMatrixFixture(rows: rows), expected)
    }

    @MainActor
    func testControllerRoutesSettingsIslandOnboardingAndQuitThroughInjectedClosures() {
        var events: [String] = []
        let onboarding = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { NSRect(x: 0, y: 0, width: 1440, height: 900) }
        )
        defer { onboarding.close() }
        let controller = MyVibeIslandAppKitRouteController(
            activateApplication: {
                events.append("activate")
            },
            showWindow: { window in
                events.append("window:\(window)")
            },
            onboardingWindowController: onboarding,
            quitApplication: {
                events.append("quit")
            }
        )

        controller.showIsland()
        controller.openSettings(SettingsDeepLink(section: .integrations, rowId: "codex"))
        controller.showOnboarding()
        controller.quit()

        XCTAssertEqual(events, [
            "activate",
            "window:settings:integrations:codex",
            "quit"
        ])
        XCTAssertNotNil(onboarding.fullscreenWindow)
    }

    @MainActor
    func testRepeatedOnboardingRouteReusesFullscreenWindowWithoutFallback() throws {
        var fallbackWindows: [String] = []
        let onboarding = MyVibeIslandAppKitOnboardingWindowController(
            screenFrame: { NSRect(x: 0, y: 0, width: 1440, height: 900) }
        )
        defer { onboarding.close() }
        let controller = MyVibeIslandAppKitRouteController(
            activateApplication: {},
            showWindow: { fallbackWindows.append($0) },
            onboardingWindowController: onboarding,
            quitApplication: {}
        )

        controller.showOnboarding()
        let first = try XCTUnwrap(onboarding.fullscreenWindow)
        controller.showOnboarding()

        XCTAssertTrue(onboarding.fullscreenWindow === first)
        XCTAssertTrue(fallbackWindows.isEmpty)
    }

    @MainActor
    func testControllerNormalizesSettingsWindowWithoutDeepLink() {
        var windows: [String] = []
        let controller = MyVibeIslandAppKitRouteController(
            activateApplication: {},
            showWindow: { window in
                windows.append(window)
            },
            quitApplication: {}
        )

        controller.openSettings(nil)

        XCTAssertEqual(windows, ["settings:general"])
    }

    @MainActor
    func testControllerPublishesLastRouteForOrchestration() {
        let controller = MyVibeIslandAppKitRouteController(
            activateApplication: {},
            showWindow: { _ in },
            quitApplication: {}
        )

        controller.openSettings(SettingsDeepLink(section: .integrations, rowId: "codex"))

        XCTAssertEqual(
            controller.lastRoute,
            .openSettings(SettingsDeepLink(section: .integrations, rowId: "codex"))
        )

        controller.quit()

        XCTAssertEqual(controller.lastRoute, .quit)
    }
}

private struct RouteControllerMatrixFixture: Codable, Equatable {
    let rows: [RouteControllerMatrixRow]
}

private struct RouteControllerMatrixRow: Codable, Equatable {
    let id: String
    let events: [String]
}
