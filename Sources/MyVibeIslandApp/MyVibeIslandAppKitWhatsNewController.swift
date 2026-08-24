import AppKit
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitWhatsNewController {
    public private(set) var state: WhatsNewStoreState
    public private(set) var lastPlan: WhatsNewStorePlan?

    private let store: WhatsNewStore
    private let presentWhatsNew: @MainActor (WhatsNewStoreState) -> Void
    private let dismissWhatsNew: @MainActor () -> Void

    public init(
        state: WhatsNewStoreState = WhatsNewStoreState(),
        store: WhatsNewStore = WhatsNewStore(),
        presentWhatsNew: @escaping @MainActor (WhatsNewStoreState) -> Void = { state in
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "What's New - \(state.pendingVersion ?? "")"
            window.contentView = NSTextField(labelWithString: state.pendingHTML ?? "")
            window.center()
            window.makeKeyAndOrderFront(nil)
        },
        dismissWhatsNew: @escaping @MainActor () -> Void = {}
    ) {
        self.state = state
        self.store = store
        self.presentWhatsNew = presentWhatsNew
        self.dismissWhatsNew = dismissWhatsNew
    }

    @discardableResult
    public func recordLaunch(currentVersion: String, rawHTML: String?) -> WhatsNewStorePlan {
        apply(.recordLaunch(currentVersion: currentVersion, rawHTML: rawHTML))
    }

    @discardableResult
    public func dismissPending() -> WhatsNewStorePlan {
        apply(.dismissPending)
    }

    private func apply(_ command: WhatsNewStoreCommand) -> WhatsNewStorePlan {
        let plan = store.plan(command, from: state)
        state = plan.nextState
        lastPlan = plan

        switch plan.action {
        case .showWhatsNew:
            presentWhatsNew(state)
        case .dismissWhatsNew:
            dismissWhatsNew()
        case .noChange:
            break
        }

        return plan
    }
}
