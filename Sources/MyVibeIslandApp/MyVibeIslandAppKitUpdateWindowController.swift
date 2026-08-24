import AppKit
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitUpdateWindowController {
    public private(set) var snapshot: UpdatePresentationSnapshot
    public private(set) var lastPlan: UpdatePresentationPlan?

    private let coordinator: UpdatePresentationCoordinator
    private let presentWindow: @MainActor (UpdatePresentationViewModel) -> Void
    private let dismissWindow: @MainActor () -> Void

    public init(
        snapshot: UpdatePresentationSnapshot = UpdatePresentationSnapshot(currentVersion: "0.0.0"),
        coordinator: UpdatePresentationCoordinator = UpdatePresentationCoordinator(),
        presentWindow: @escaping @MainActor (UpdatePresentationViewModel) -> Void = { viewModel in
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Update - \(viewModel.snapshot.phase.rawValue)"
            window.contentView = NSTextField(labelWithString: viewModel.pill.label)
            window.center()
            window.makeKeyAndOrderFront(nil)
        },
        dismissWindow: @escaping @MainActor () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.coordinator = coordinator
        self.presentWindow = presentWindow
        self.dismissWindow = dismissWindow
    }

    public func checkForUpdates() {
        apply(.startManualCheck)
    }

    public func foundUpdate(
        version: String,
        critical: Bool = false,
        informationOnly: Bool = false,
        majorUpgrade: Bool = false,
        alreadyDownloaded: Bool = false,
        notes: [ReleaseNotesSection] = []
    ) {
        apply(.foundUpdate(
            version: version,
            critical: critical,
            informationOnly: informationOnly,
            majorUpgrade: majorUpgrade,
            alreadyDownloaded: alreadyDownloaded,
            notes: notes
        ))
    }

    public func skipVersion() {
        apply(.skipVersion)
    }

    public func remindLater() {
        apply(.remindLater)
    }

    public func fail(_ errorHint: String) {
        apply(.fail(errorHint))
    }

    private func apply(_ command: UpdatePresentationCommand) {
        let plan = coordinator.plan(command, from: snapshot)
        snapshot = plan.nextSnapshot
        lastPlan = plan

        switch plan.presentedAction {
        case .showUpdateWindow:
            presentWindow(UpdatePresentationViewModel(snapshot: snapshot))
        case .dismissUpdateWindow:
            dismissWindow()
        case .none:
            if snapshot.phase == .checking || snapshot.phase == .failed {
                presentWindow(UpdatePresentationViewModel(snapshot: snapshot))
            }
        }
    }
}
