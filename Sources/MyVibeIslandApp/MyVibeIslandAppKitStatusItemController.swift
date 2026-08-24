import AppKit

public enum MyVibeIslandAppKitStatusItemAction: Equatable {
    case installMenu(title: String)
    case removeStatusItem
}

@MainActor
public final class MyVibeIslandAppKitStatusItemController {
    public private(set) var statusItem: NSStatusItem?
    public private(set) var lastAction: MyVibeIslandAppKitStatusItemAction?

    private let createStatusItem: @MainActor () -> NSStatusItem
    private let removeStatusItem: @MainActor (NSStatusItem) -> Void

    public init(
        createStatusItem: @escaping @MainActor () -> NSStatusItem = {
            NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        },
        removeStatusItem: @escaping @MainActor (NSStatusItem) -> Void = { item in
            NSStatusBar.system.removeStatusItem(item)
        }
    ) {
        self.createStatusItem = createStatusItem
        self.removeStatusItem = removeStatusItem
    }

    public func install(_ menu: NSMenu?) {
        guard let menu else {
            removeCurrentStatusItem()
            return
        }

        let item = statusItem ?? createStatusItem()
        item.menu = menu
        statusItem = item
        lastAction = .installMenu(title: menu.title)
    }

    private func removeCurrentStatusItem() {
        guard let item = statusItem else {
            return
        }

        item.menu = nil
        removeStatusItem(item)
        statusItem = nil
        lastAction = .removeStatusItem
    }
}
