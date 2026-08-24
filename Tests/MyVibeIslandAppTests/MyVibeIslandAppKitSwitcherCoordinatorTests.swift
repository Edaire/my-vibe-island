import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class MyVibeIslandAppKitSwitcherCoordinatorTests: XCTestCase {
    func testCoordinatorOwnsNavigationStateIncludingReverseAndDuplicates() {
        let coordinator = makeCoordinator()

        coordinator.open(sessionIDs: ["same", "middle", "same"], highlighted: "same")
        coordinator.navigate(.up)
        XCTAssertEqual(coordinator.state.highlightedIndex, 2)

        coordinator.navigate(.down, reverse: true)
        XCTAssertEqual(coordinator.state.highlightedIndex, 1)
    }

    func testSubmitUsesOnlyStateHighlightThenJumpsAndCollapses() {
        var jumped: [String] = []
        var wasOpenDuringJump = false
        var coordinator: MyVibeIslandAppKitSwitcherCoordinator!
        coordinator = makeCoordinator(jump: {
            jumped.append($0)
            wasOpenDuringJump = coordinator.state.isOpen
        })
        coordinator.open(sessionIDs: ["first", "exact"], highlighted: "exact")

        coordinator.submitHighlighted()

        XCTAssertEqual(jumped, ["exact"])
        XCTAssertTrue(wasOpenDuringJump)
        XCTAssertFalse(coordinator.state.isOpen)
        XCTAssertNil(coordinator.state.highlightedID)
    }

    func testEmptySubmitDoesNotJump() {
        var jumped: [String] = []
        let coordinator = makeCoordinator(jump: { jumped.append($0) })

        coordinator.open(sessionIDs: [], highlighted: nil)
        coordinator.submitHighlighted()

        XCTAssertTrue(jumped.isEmpty)
    }

    func testCollapseClosesStateAndRoutesPanelEvents() {
        var commands: [PanelInteractionCommand] = []
        let coordinator = makeCoordinator(route: { commands.append($0) })

        coordinator.open(sessionIDs: ["session"], highlighted: nil)
        coordinator.collapse()
        XCTAssertFalse(coordinator.state.isOpen)
        XCTAssertTrue(commands.contains(.outsideClick))
        XCTAssertTrue(commands.contains(.setKeyboardFocusNeeded(false)))
    }

    private func makeCoordinator(
        jump: @escaping (String) -> Void = { _ in },
        route: @escaping (PanelInteractionCommand) -> Void = { _ in }
    ) -> MyVibeIslandAppKitSwitcherCoordinator {
        MyVibeIslandAppKitSwitcherCoordinator(
            jumpToSession: jump,
            routePanelInteraction: route
        )
    }
}
