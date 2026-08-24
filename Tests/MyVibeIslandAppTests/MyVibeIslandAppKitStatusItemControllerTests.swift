import AppKit
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitStatusItemControllerTests: XCTestCase {
    @MainActor
    func testStatusItemControllerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            StatusItemControllerMatrixFixture.self,
            from: try AppFixtureLoader.data("app/status-item-controller-matrix")
        )
        var events: [String] = []
        let fakeItem = NSStatusItem()
        let controller = MyVibeIslandAppKitStatusItemController(
            createStatusItem: {
                events.append("create")
                return fakeItem
            },
            removeStatusItem: { item in
                events.append("remove:\(item.menu?.title ?? "nil")")
            }
        )

        controller.install(NSMenu(title: "First"))
        let first = row(id: "first-install", controller: controller, item: fakeItem, events: events)

        controller.install(NSMenu(title: "Second"))
        let second = row(id: "second-install", controller: controller, item: fakeItem, events: events)

        controller.install(nil)
        let removed = row(id: "remove", controller: controller, item: fakeItem, events: events)

        XCTAssertEqual(
            StatusItemControllerMatrixFixture(rows: [first, second, removed]),
            expected
        )
    }

    @MainActor
    func testControllerCreatesStatusItemAndInstallsMenu() {
        var events: [String] = []
        let fakeItem = NSStatusItem()
        let controller = MyVibeIslandAppKitStatusItemController(
            createStatusItem: {
                events.append("create")
                return fakeItem
            },
            removeStatusItem: { _ in
                events.append("remove")
            }
        )
        let menu = NSMenu(title: "My Vibe Island Menu")

        controller.install(menu)

        XCTAssertTrue(controller.statusItem === fakeItem)
        XCTAssertTrue(fakeItem.menu === menu)
        XCTAssertEqual(events, ["create"])
    }

    @MainActor
    func testControllerReusesStatusItemForMenuUpdates() {
        var createCount = 0
        let fakeItem = NSStatusItem()
        let controller = MyVibeIslandAppKitStatusItemController(
            createStatusItem: {
                createCount += 1
                return fakeItem
            },
            removeStatusItem: { _ in }
        )

        controller.install(NSMenu(title: "First"))
        controller.install(NSMenu(title: "Second"))

        XCTAssertEqual(createCount, 1)
        XCTAssertEqual(fakeItem.menu?.title, "Second")
    }

    @MainActor
    func testControllerRemovesStatusItemWhenMenuIsNil() {
        var removedItems: [NSStatusItem] = []
        let fakeItem = NSStatusItem()
        let controller = MyVibeIslandAppKitStatusItemController(
            createStatusItem: { fakeItem },
            removeStatusItem: { item in
                removedItems.append(item)
            }
        )

        controller.install(NSMenu(title: "Visible"))
        controller.install(nil)

        XCTAssertNil(controller.statusItem)
        XCTAssertNil(fakeItem.menu)
        XCTAssertEqual(removedItems.count, 1)
        XCTAssertTrue(removedItems[0] === fakeItem)
    }

    @MainActor
    func testControllerPublishesLastStatusItemActionForOrchestration() {
        let fakeItem = NSStatusItem()
        let controller = MyVibeIslandAppKitStatusItemController(
            createStatusItem: { fakeItem },
            removeStatusItem: { _ in }
        )

        controller.install(NSMenu(title: "Visible"))

        XCTAssertEqual(controller.lastAction, .installMenu(title: "Visible"))

        controller.install(nil)

        XCTAssertEqual(controller.lastAction, .removeStatusItem)
    }

    @MainActor
    private func row(
        id: String,
        controller: MyVibeIslandAppKitStatusItemController,
        item: NSStatusItem,
        events: [String]
    ) -> StatusItemControllerMatrixRow {
        StatusItemControllerMatrixRow(
            id: id,
            eventCount: events.count,
            events: events,
            hasControllerItem: controller.statusItem != nil,
            itemMenuTitle: item.menu?.title,
            lastAction: controller.lastAction?.summary
        )
    }
}

private struct StatusItemControllerMatrixFixture: Codable, Equatable {
    let rows: [StatusItemControllerMatrixRow]
}

private struct StatusItemControllerMatrixRow: Codable, Equatable {
    let id: String
    let eventCount: Int
    let events: [String]
    let hasControllerItem: Bool
    let itemMenuTitle: String?
    let lastAction: String?
}

private extension MyVibeIslandAppKitStatusItemAction {
    var summary: String {
        switch self {
        case let .installMenu(title):
            return "installMenu:\(title)"
        case .removeStatusItem:
            return "removeStatusItem"
        }
    }
}
