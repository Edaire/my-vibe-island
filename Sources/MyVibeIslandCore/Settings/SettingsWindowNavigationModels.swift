import Foundation

public enum SettingsSection: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    case general
    case integrations
    case notifications
    case display
    case sound
    case usage
    case shortcuts
    case sshRemote
    case labs
    case about

    public static let defaultSidebarSections: [SettingsSection] = [
        .general,
        .integrations,
        .notifications,
        .display,
        .sound,
        .usage,
        .shortcuts,
        .sshRemote,
        .labs,
        .about
    ]

    public var title: String {
        switch self {
        case .general:
            return "General"
        case .integrations:
            return "Integrations"
        case .notifications:
            return "Notifications"
        case .display:
            return "Display"
        case .sound:
            return "Sound"
        case .usage:
            return "Usage"
        case .shortcuts:
            return "Shortcuts"
        case .sshRemote:
            return "SSH Remote"
        case .labs:
            return "Labs"
        case .about:
            return "About"
        }
    }

    public var iconName: String {
        switch self {
        case .general:
            return "gearshape"
        case .integrations:
            return "puzzlepiece.extension"
        case .notifications:
            return "bell"
        case .display:
            return "display"
        case .sound:
            return "speaker.wave.2"
        case .usage:
            return "chart.bar"
        case .shortcuts:
            return "keyboard"
        case .sshRemote:
            return "network"
        case .labs:
            return "flask"
        case .about:
            return "info.circle"
        }
    }
}

public enum SettingsDeepLinkHighlightReason: String, Codable, Equatable, Sendable {
    case userRequested
    case repairRequired
    case missingPermission
    case validationFailed
}

public enum SettingsDeepLinkActionHint: String, Codable, Equatable, Sendable {
    case openDiagnostics
    case openRepair
    case revealRow
    case startTrustFlow
}

public struct SettingsDeepLink: Codable, Equatable, Sendable {
    public let section: SettingsSection
    public let rowId: String?
    public let highlightReason: SettingsDeepLinkHighlightReason?
    public let actionHint: SettingsDeepLinkActionHint?

    public init(
        section: SettingsSection,
        rowId: String? = nil,
        highlightReason: SettingsDeepLinkHighlightReason? = nil,
        actionHint: SettingsDeepLinkActionHint? = nil
    ) {
        self.section = section
        self.rowId = rowId
        self.highlightReason = highlightReason
        self.actionHint = actionHint
    }
}

public struct SettingsDetailHeader: Codable, Equatable, Sendable {
    public let section: SettingsSection

    public init(section: SettingsSection) {
        self.section = section
    }

    public var title: String { section.title }
    public var subtitle: String? { nil }
    public var iconName: String { section.iconName }
    public var statusBadge: String? { nil }
    public var helpLink: String? { nil }
}

public struct SettingsWindowState: Codable, Equatable, Sendable {
    public let isOpen: Bool
    public let availableSections: [SettingsSection]
    public let selectedSection: SettingsSection
    public let detailHeader: SettingsDetailHeader
    public let deepLink: SettingsDeepLink?
    public let searchQuery: String

    public init(
        isOpen: Bool = false,
        availableSections: [SettingsSection] = SettingsSection.defaultSidebarSections,
        selectedSection: SettingsSection = .general,
        detailHeader: SettingsDetailHeader? = nil,
        deepLink: SettingsDeepLink? = nil,
        searchQuery: String = ""
    ) {
        let sections = availableSections.isEmpty ? SettingsSection.defaultSidebarSections : availableSections
        self.isOpen = isOpen
        self.availableSections = sections
        self.selectedSection = sections.contains(selectedSection) ? selectedSection : sections[0]
        self.detailHeader = detailHeader ?? SettingsDetailHeader(section: self.selectedSection)
        self.deepLink = deepLink
        self.searchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SettingsWindowCommand: Equatable, Sendable {
    case open(deepLink: SettingsDeepLink?)
    case reopen
    case close
    case selectSection(SettingsSection)
    case updateSearch(String)
}

public enum SettingsWindowControllerAction: String, Codable, Equatable, Sendable {
    case showWindow
    case closeWindow
    case selectSection
    case updateSearch
    case ignoredUnavailableSection
}

public struct SettingsWindowControllerPlan: Equatable, Sendable {
    public let action: SettingsWindowControllerAction
    public let nextState: SettingsWindowState

    public init(action: SettingsWindowControllerAction, nextState: SettingsWindowState) {
        self.action = action
        self.nextState = nextState
    }
}

public struct SettingsWindowController: Sendable {
    public init() {}

    public func plan(_ command: SettingsWindowCommand, from state: SettingsWindowState) -> SettingsWindowControllerPlan {
        switch command {
        case let .open(deepLink):
            let section = deepLink?.section ?? state.selectedSection
            return SettingsWindowControllerPlan(
                action: .showWindow,
                nextState: SettingsWindowState(
                    isOpen: true,
                    availableSections: state.availableSections,
                    selectedSection: section,
                    deepLink: deepLink,
                    searchQuery: state.searchQuery
                )
            )

        case .reopen:
            return SettingsWindowControllerPlan(
                action: .showWindow,
                nextState: SettingsWindowState(
                    isOpen: true,
                    availableSections: state.availableSections,
                    selectedSection: state.selectedSection,
                    deepLink: state.deepLink,
                    searchQuery: state.searchQuery
                )
            )

        case .close:
            return SettingsWindowControllerPlan(
                action: .closeWindow,
                nextState: SettingsWindowState(
                    isOpen: false,
                    availableSections: state.availableSections,
                    selectedSection: state.selectedSection,
                    deepLink: state.deepLink,
                    searchQuery: state.searchQuery
                )
            )

        case let .selectSection(section):
            guard state.availableSections.contains(section) else {
                return SettingsWindowControllerPlan(action: .ignoredUnavailableSection, nextState: state)
            }

            return SettingsWindowControllerPlan(
                action: .selectSection,
                nextState: SettingsWindowState(
                    isOpen: state.isOpen,
                    availableSections: state.availableSections,
                    selectedSection: section,
                    deepLink: nil,
                    searchQuery: state.searchQuery
                )
            )

        case let .updateSearch(query):
            return SettingsWindowControllerPlan(
                action: .updateSearch,
                nextState: SettingsWindowState(
                    isOpen: state.isOpen,
                    availableSections: state.availableSections,
                    selectedSection: state.selectedSection,
                    deepLink: state.deepLink,
                    searchQuery: query
                )
            )
        }
    }
}
