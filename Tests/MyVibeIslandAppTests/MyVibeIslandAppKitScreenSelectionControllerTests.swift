import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitScreenSelectionControllerTests: XCTestCase {
    @MainActor
    func testScreenSelectionControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            ScreenSelectionControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/screen-selection-controller-matrix")
        )

        let builtIn = ScreenDescriptor(identifier: "built-in", displayName: "Built-In", isBuiltIn: true, hasNotch: true, isMain: true)
        let external = ScreenDescriptor(identifier: "external", displayName: "External", isBuiltIn: false, hasNotch: false, isMain: false)
        let actual = ScreenSelectionControllerMatrixFixture(rows: [
            row(
                id: "default-refresh-manual",
                initialSnapshot: ScreenSelectionSnapshot(),
                commands: [
                    .refresh([builtIn, external]),
                    .selectMode(.builtInNotchDisplay),
                    .selectDisplay("external")
                ]
            ),
            row(
                id: "follow-focus-dismiss-tip",
                initialSnapshot: ScreenSelectionSnapshot(mode: .followKeyboardFocus),
                commands: [
                    .refresh([builtIn, external]),
                    .focusDisplay("external"),
                    .focusDisplay("missing"),
                    .dismissSwitchTip
                ]
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testControllerAppliesTargetOnlyWhenScreenSelectionTargetChanges() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitScreenSelectionController(
            applyTargetScreen: { target in
                events.append("target:\(target.identifier)")
            }
        )
        let screens = [
            ScreenDescriptor(identifier: "built-in", displayName: "Built-in", isBuiltIn: true, hasNotch: true, isMain: true),
            ScreenDescriptor(identifier: "side", displayName: "Side", isBuiltIn: false, hasNotch: false, isMain: false)
        ]

        let initial = controller.refreshScreens(screens)
        let unchanged = controller.selectMode(.builtInNotchDisplay)
        let manual = controller.selectDisplay("side")

        XCTAssertTrue(initial.targetDidChange)
        XCTAssertFalse(unchanged.targetDidChange)
        XCTAssertTrue(manual.targetDidChange)
        XCTAssertEqual(controller.snapshot.target?.identifier, "side")
        XCTAssertEqual(events, [
            "target:built-in",
            "target:side"
        ])
    }

    @MainActor
    func testControllerTracksFocusAndTipStateWithoutApplyingUnchangedTarget() {
        var events: [String] = []
        let controller = MyVibeIslandAppKitScreenSelectionController(
            snapshot: ScreenSelectionSnapshot(mode: .followKeyboardFocus),
            applyTargetScreen: { target in
                events.append("target:\(target.identifier)")
            }
        )
        let screens = [
            ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: true, hasNotch: true, isMain: true),
            ScreenDescriptor(identifier: "external", displayName: "External", isBuiltIn: false, hasNotch: false, isMain: false)
        ]

        _ = controller.refreshScreens(screens)
        let focused = controller.focusDisplay("external")
        let missingFocus = controller.focusDisplay("missing")
        let dismissed = controller.dismissSwitchTip()

        XCTAssertTrue(focused.targetDidChange)
        XCTAssertFalse(missingFocus.targetDidChange)
        XCTAssertFalse(dismissed.targetDidChange)
        XCTAssertEqual(controller.snapshot.focusedScreenIdentifier, "external")
        XCTAssertTrue(controller.snapshot.switchTipDismissed)
        XCTAssertEqual(events, [
            "target:main",
            "target:external"
        ])
    }

    @MainActor
    func testControllerPublishesLastScreenSelectionPlanForOrchestration() {
        let controller = MyVibeIslandAppKitScreenSelectionController(
            applyTargetScreen: { _ in }
        )
        let screens = [
            ScreenDescriptor(identifier: "main", displayName: "Main", isBuiltIn: true, hasNotch: true, isMain: true)
        ]

        _ = controller.refreshScreens(screens)

        XCTAssertEqual(controller.lastPlan?.nextSnapshot.target?.identifier, "main")
        XCTAssertEqual(controller.lastPlan?.targetDidChange, true)
    }

    @MainActor
    private func row(
        id: String,
        initialSnapshot: ScreenSelectionSnapshot,
        commands: [ScreenSelectionControllerFixtureCommand]
    ) -> ScreenSelectionControllerMatrixRow {
        var events: [String] = []
        let controller = MyVibeIslandAppKitScreenSelectionController(
            snapshot: initialSnapshot,
            applyTargetScreen: { target in
                events.append("target:\(target.identifier)")
            }
        )
        let plans = commands.map { command in
            switch command {
            case let .refresh(screens):
                return controller.refreshScreens(screens)
            case let .selectMode(mode):
                return controller.selectMode(mode)
            case let .selectDisplay(identifier):
                return controller.selectDisplay(identifier)
            case let .focusDisplay(identifier):
                return controller.focusDisplay(identifier)
            case .dismissSwitchTip:
                return controller.dismissSwitchTip()
            }
        }

        return ScreenSelectionControllerMatrixRow(
            id: id,
            initialSnapshot: ScreenSelectionSnapshotSummary(initialSnapshot),
            commands: commands.map(\.summary),
            targetDidChange: plans.map(\.targetDidChange),
            finalSnapshot: ScreenSelectionSnapshotSummary(controller.snapshot),
            lastPlanTargetDidChange: controller.lastPlan?.targetDidChange,
            events: events
        )
    }
}

private struct ScreenSelectionControllerMatrixFixture: Codable, Equatable {
    let rows: [ScreenSelectionControllerMatrixRow]
}

private struct ScreenSelectionControllerMatrixRow: Codable, Equatable {
    let id: String
    let initialSnapshot: ScreenSelectionSnapshotSummary
    let commands: [String]
    let targetDidChange: [Bool]
    let finalSnapshot: ScreenSelectionSnapshotSummary
    let lastPlanTargetDidChange: Bool?
    let events: [String]
}

private struct ScreenSelectionSnapshotSummary: Codable, Equatable {
    let mode: String
    let availableScreenIdentifiers: [String]
    let targetIdentifier: String?
    let manualScreenIdentifier: String?
    let focusedScreenIdentifier: String?
    let switchTipDismissed: Bool

    init(_ snapshot: ScreenSelectionSnapshot) {
        self.mode = snapshot.mode.rawValue
        self.availableScreenIdentifiers = snapshot.availableScreens.map(\.identifier)
        self.targetIdentifier = snapshot.target?.identifier
        self.manualScreenIdentifier = snapshot.manualScreenIdentifier
        self.focusedScreenIdentifier = snapshot.focusedScreenIdentifier
        self.switchTipDismissed = snapshot.switchTipDismissed
    }
}

private enum ScreenSelectionControllerFixtureCommand {
    case refresh([ScreenDescriptor])
    case selectMode(AppScreenSelectionMode)
    case selectDisplay(String)
    case focusDisplay(String)
    case dismissSwitchTip

    var summary: String {
        switch self {
        case let .refresh(screens):
            return "refresh:\(screens.map(\.identifier).joined(separator: ","))"
        case let .selectMode(mode):
            return "selectMode:\(mode.rawValue)"
        case let .selectDisplay(identifier):
            return "selectDisplay:\(identifier)"
        case let .focusDisplay(identifier):
            return "focusDisplay:\(identifier)"
        case .dismissSwitchTip:
            return "dismissSwitchTip"
        }
    }
}
