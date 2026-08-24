public enum AppShellPlatformEvent: Equatable, Sendable {
    case didFinishLaunching(AppShellLaunchRequest)
    case reopen(behavior: DockReopenBehavior)
    case willTerminate
    case menuEntrySelected(StatusItemMenuEntry)
    case menuCommand(AppCommand)
    case overlayGesture(OverlaySessionGesture)
    case placementChanged(DisplayPlacementPlan)
    case presentationChanged(NotchPresentationState)
    case menuSnapshotChanged(AppMenuSnapshot)
}

public enum AppShellIgnoredEventReason: String, Codable, Equatable, Sendable {
    case disabledMenuEntry
    case nonCommandMenuEntry
    case commandlessMenuEntry
    case reopenIgnored
}

public struct AppShellEventRoute: Equatable, Sendable {
    public let commands: [AppShellCommand]
    public let ignoredReason: AppShellIgnoredEventReason?

    public init(
        commands: [AppShellCommand],
        ignoredReason: AppShellIgnoredEventReason? = nil
    ) {
        self.commands = commands
        self.ignoredReason = ignoredReason
    }
}

public struct AppShellEventRouter: Sendable {
    public init() {}

    public func route(_ event: AppShellPlatformEvent) -> AppShellEventRoute {
        switch event {
        case let .didFinishLaunching(request):
            return AppShellEventRoute(commands: [.launch(request)])

        case let .reopen(behavior):
            return routeReopen(behavior)

        case .willTerminate:
            return AppShellEventRoute(commands: [.terminate])

        case let .menuEntrySelected(entry):
            return routeMenuEntry(entry)

        case let .menuCommand(command):
            return AppShellEventRoute(commands: [.menu(command)])

        case let .overlayGesture(gesture):
            return AppShellEventRoute(commands: [.overlay(.sessionGesture(gesture))])

        case let .placementChanged(placement):
            return AppShellEventRoute(commands: [.replacePlacement(placement)])

        case let .presentationChanged(presentation):
            return AppShellEventRoute(commands: [.replacePresentation(presentation)])

        case let .menuSnapshotChanged(snapshot):
            return AppShellEventRoute(commands: [.replaceMenuSnapshot(snapshot)])
        }
    }

    private func routeReopen(_ behavior: DockReopenBehavior) -> AppShellEventRoute {
        switch behavior {
        case .showIsland:
            return AppShellEventRoute(commands: [.reopen(.island)])
        case .openSettings:
            return AppShellEventRoute(commands: [.reopen(.settings(nil))])
        case .ignore:
            return AppShellEventRoute(commands: [], ignoredReason: .reopenIgnored)
        }
    }

    private func routeMenuEntry(_ entry: StatusItemMenuEntry) -> AppShellEventRoute {
        guard entry.kind == .command else {
            return AppShellEventRoute(commands: [], ignoredReason: .nonCommandMenuEntry)
        }
        guard entry.isEnabled else {
            return AppShellEventRoute(commands: [], ignoredReason: .disabledMenuEntry)
        }
        guard let command = entry.command else {
            return AppShellEventRoute(commands: [], ignoredReason: .commandlessMenuEntry)
        }

        return AppShellEventRoute(commands: [.menu(command)])
    }
}
