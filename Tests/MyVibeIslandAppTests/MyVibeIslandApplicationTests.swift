import AppKit
import CoreGraphics
import XCTest
import MyVibeIslandCore
@testable import MyVibeIslandApp

final class MyVibeIslandApplicationTests: XCTestCase {
    func testApplicationLaunchPlanMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ApplicationLaunchPlanMatrixFixture.self,
            from: try AppFixtureLoader.data("app/application-launch-plan-matrix")
        )

        let application = MyVibeIslandApplication()
        let plan = application.prepareLaunch()
        let actual = ApplicationLaunchPlanMatrixFixture(rows: [
            ApplicationLaunchPlanMatrixRow(
                id: "default-platform-launch",
                intentCount: plan.summary.intentCount,
                lifecycleIntentCount: plan.summary.lifecycleIntentCount,
                runtimeStartIntentCount: plan.summary.runtimeStartIntentCount,
                notchWindowIntentCount: plan.summary.notchWindowIntentCount,
                statusItemMenuEntryCount: plan.summary.statusItemMenuEntryCount,
                route: plan.launchPlan.summary.route.rawValue,
                targetDisplayName: plan.launchPlan.summary.targetDisplayName
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testApplicationPreparesDefaultPlatformLaunchPlan() {
        let application = MyVibeIslandApplication()

        let plan = application.prepareLaunch()

        XCTAssertEqual(plan.summary.intentCount, 36)
        XCTAssertEqual(plan.summary.runtimeStartIntentCount, 19)
        XCTAssertEqual(plan.summary.statusItemMenuEntryCount, 14)
        XCTAssertEqual(plan.launchPlan.summary.targetDisplayName, "Built-in Display")
        XCTAssertEqual(plan.launchPlan.summary.route.rawValue, "island")
    }

    func testApplicationBuildsLaunchPlacementFromLiveScreenGeometry() {
        let application = MyVibeIslandApplication.production(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTopInset: 32
        )

        XCTAssertEqual(
            application.launchBootstrap.configuration.placementInput.closedSize,
            OriginalIslandGeometryResolver.panelSize
        )
        XCTAssertEqual(
            application.launchBootstrap.configuration.placementInput.expandedSize,
            OriginalIslandGeometryResolver.panelSize
        )

        let placement = application.prepareLaunch().launchPlan.request.placement

        XCTAssertEqual(placement.closedFrame, DisplayFrame(x: 416, y: 402, width: 680, height: 580))
        XCTAssertEqual(placement.expandedFrame, DisplayFrame(x: 416, y: 402, width: 680, height: 580))
        XCTAssertEqual(placement.anchor, DisplayPoint(x: 756, y: 982))
    }

    func testProductionPlacementPreservesExternalScreenGlobalOrigin() {
        let input = appKitProductionPlacementInput(
            screenFrame: DisplayFrame(x: -1920, y: -120, width: 2560, height: 1440),
            safeAreaTopInset: 0
        )

        let placement = DisplayPlacementResolver().resolve(input)

        XCTAssertEqual(placement.closedFrame, DisplayFrame(x: -980, y: 740, width: 680, height: 580))
        XCTAssertEqual(placement.anchor, DisplayPoint(x: -640, y: 1320))
    }

    func testProductionPrimaryScreenPrefersOrderedFirstOverAppKitMain() {
        let selected = productionPrimaryScreen(
            orderedScreens: ["ordered-first", "appkit-main"],
            mainScreen: "appkit-main"
        )

        XCTAssertEqual(selected, "ordered-first")
    }

    @MainActor
    func testAppKitProductionLaunchUsesOrderedFirstScreenTargetMetadata() throws {
        let screen = try XCTUnwrap(productionPrimaryScreen(
            orderedScreens: NSScreen.screens,
            mainScreen: NSScreen.main
        ))
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let expectedTarget = ScreenTarget(
            identifier: displayID.map(String.init) ?? screen.localizedName,
            displayName: screen.localizedName,
            isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
            isMain: screen == NSScreen.main
        )

        let plan = MyVibeIslandApplication.production().prepareLaunch()

        XCTAssertEqual(plan.launchPlan.request.target, expectedTarget)
        XCTAssertTrue(plan.intents.contains(.applyTargetScreen(expectedTarget.identifier)))
    }

    @MainActor
    func testProductionFullLaunchIntentsApplyInjectedScreenTarget() {
        let target = ScreenTarget(
            identifier: "ordered-first",
            displayName: "Ordered First",
            isBuiltIn: false,
            isMain: false
        )
        let application = MyVibeIslandApplication.production(
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTopInset: 0,
            target: target
        )
        let plan = application.prepareLaunch()
        var appliedTargetIdentifiers: [String] = []
        let result = MyVibeIslandAppKitPlatformIntentExecutor(
            applyTargetScreen: { appliedTargetIdentifiers.append($0) }
        ).execute(plan.intents)

        XCTAssertEqual(plan.launchPlan.request.target, target)
        XCTAssertEqual(result.executedIntents, plan.intents)
        XCTAssertEqual(appliedTargetIdentifiers, ["ordered-first"])
        XCTAssertFalse(plan.intents.contains(.applyTargetScreen("main")))
    }
}

private struct ApplicationLaunchPlanMatrixFixture: Codable, Equatable {
    let rows: [ApplicationLaunchPlanMatrixRow]
}

private struct ApplicationLaunchPlanMatrixRow: Codable, Equatable {
    let id: String
    let intentCount: Int
    let lifecycleIntentCount: Int
    let runtimeStartIntentCount: Int
    let notchWindowIntentCount: Int
    let statusItemMenuEntryCount: Int
    let route: String
    let targetDisplayName: String
}
