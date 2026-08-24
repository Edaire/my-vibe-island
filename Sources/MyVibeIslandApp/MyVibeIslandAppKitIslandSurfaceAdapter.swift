import MyVibeIslandCore

public enum MyVibeIslandAppKitIslandSurfaceItemStyle: String, Equatable, Sendable {
    case compactPill = "compact-pill"
    case expandedPanel = "expanded-panel"
    case sessionCard = "session-card"
    case notificationPeek = "notification-peek"
    case usageInfo = "usage-info"
    case updatePill = "update-pill"
    case switcher
    case onboardingGlow = "onboarding-glow"
    case questionAction = "question-action"

    public init(section: IslandSurfaceSection) {
        switch section {
        case .compactPill:
            self = .compactPill
        case .expandedPanel:
            self = .expandedPanel
        case .sessionCards:
            self = .sessionCard
        case .notificationPeek:
            self = .notificationPeek
        case .usageInfo:
            self = .usageInfo
        case .updatePill:
            self = .updatePill
        case .switcher:
            self = .switcher
        case .onboardingGlow:
            self = .onboardingGlow
        case .questionActions:
            self = .questionAction
        case .actionRequests:
            self = .questionAction
        }
    }
}

public struct MyVibeIslandAppKitIslandSurfaceItemDescriptor: Equatable, Sendable {
    public let section: IslandSurfaceSection
    public let style: MyVibeIslandAppKitIslandSurfaceItemStyle
    public let accessibilityLabel: String
    public let detailLabel: String?
    public let secondaryLabel: String?
    public let sessionBadges: [String]
    public let sessionIds: [String]
    public let interactionHint: IslandSurfaceInteractionHint
    public let isInteractive: Bool
    public let actionRequestPreviews: [ActionRequestPreview]
    public let sessionPreviews: [SessionCardPreview]

    public init(
        section: IslandSurfaceSection,
        style: MyVibeIslandAppKitIslandSurfaceItemStyle? = nil,
        accessibilityLabel: String,
        detailLabel: String? = nil,
        secondaryLabel: String? = nil,
        sessionBadges: [String] = [],
        sessionIds: [String] = [],
        interactionHint: IslandSurfaceInteractionHint = .none,
        isInteractive: Bool = false,
        actionRequestPreviews: [ActionRequestPreview] = [],
        sessionPreviews: [SessionCardPreview] = []
    ) {
        self.section = section
        self.style = style ?? MyVibeIslandAppKitIslandSurfaceItemStyle(section: section)
        self.accessibilityLabel = accessibilityLabel
        self.detailLabel = detailLabel
        self.secondaryLabel = secondaryLabel
        self.sessionBadges = sessionBadges
        self.sessionIds = sessionIds
        self.interactionHint = interactionHint
        self.isInteractive = isInteractive
        self.actionRequestPreviews = actionRequestPreviews
        self.sessionPreviews = sessionPreviews
    }
}

public struct MyVibeIslandAppKitIslandSurfaceDescriptor: Equatable, Sendable {
    public let isVisible: Bool
    public let contentSize: DisplaySize
    public let items: [MyVibeIslandAppKitIslandSurfaceItemDescriptor]

    public init(
        isVisible: Bool,
        contentSize: DisplaySize,
        items: [MyVibeIslandAppKitIslandSurfaceItemDescriptor]
    ) {
        self.isVisible = isVisible
        self.contentSize = contentSize
        self.items = items
    }
}

public struct MyVibeIslandAppKitIslandSurfaceAdapter: Sendable {
    public init() {}

    public func makeSurfaceDescriptor(
        from renderList: IslandSurfaceRenderList
    ) -> MyVibeIslandAppKitIslandSurfaceDescriptor {
        MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: !renderList.items.isEmpty,
            contentSize: renderList.sections.contentSize,
            items: renderList.items.map { item in
                makeItemDescriptor(from: item, sections: renderList.sections)
            }
        )
    }

    private func makeItemDescriptor(
        from item: IslandSurfaceRenderItem,
        sections: IslandSurfaceSections
    ) -> MyVibeIslandAppKitIslandSurfaceItemDescriptor {
        MyVibeIslandAppKitIslandSurfaceItemDescriptor(
            section: item.section,
            accessibilityLabel: accessibilityLabel(for: item.section, sections: sections),
            detailLabel: detailLabel(for: item, sections: sections),
            secondaryLabel: secondaryLabel(for: item.sessionIds),
            sessionBadges: item.sessionIds,
            sessionIds: item.sessionIds,
            interactionHint: item.interactionHint,
            isInteractive: item.interactionHint != .none || !item.actionRequestPreviews.isEmpty,
            actionRequestPreviews: item.actionRequestPreviews,
            sessionPreviews: item.sessionPreviews ?? []
        )
    }

    private func secondaryLabel(for sessionIds: [String]) -> String? {
        guard !sessionIds.isEmpty else {
            return nil
        }

        return sessionIds.count == 1 ? "1 session" : "\(sessionIds.count) sessions"
    }

    private func detailLabel(
        for item: IslandSurfaceRenderItem,
        sections: IslandSurfaceSections
    ) -> String? {
        let section = item.section

        if let focusedDetailLabel = focusedSessionDetailLabel(for: item) {
            return focusedDetailLabel
        }

        if section == .compactPill {
            return compactPillDetailLabel(for: sections.rightSlotContent)
        }

        if section == .notificationPeek {
            return notificationPeekDetailLabel(for: item.sessionIds)
        }

        if section == .usageInfo {
            return usageInfoDetailLabel(for: sections.usageInfoBar)
        }

        if section == .onboardingGlow {
            return onboardingDetailLabel(for: sections.onboardingStep)
        }

        if section == .questionActions {
            return questionActionsDetailLabel(for: sections.questionSelectionCount)
        }

        guard section == .updatePill else {
            return nil
        }

        return updatePillDetailLabel(for: sections.updatePill)
    }

    private func notificationPeekDetailLabel(for sessionIds: [String]) -> String? {
        guard !sessionIds.isEmpty else {
            return nil
        }

        return sessionIds.count == 1
            ? "Notification session: \(sessionIds[0])"
            : "Notification sessions: \(sessionIds.joined(separator: ", "))"
    }

    private func updatePillDetailLabel(for pill: UpdateAvailablePill) -> String? {
        var parts: [String] = []

        if let targetVersion = pill.targetVersion {
            parts.append("Target version \(targetVersion)")
        }

        if pill.installReady {
            parts.append("Ready to install")
        }

        if let actionLabel = updateActionDetailLabel(for: pill.action) {
            parts.append(actionLabel)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    private func updateActionDetailLabel(for action: UpdatePresentationAction) -> String? {
        switch action {
        case .openUpdateWindow:
            return "Opens update window"
        case .checkAgain:
            return "Checks for updates"
        case .downloadAndInstall:
            return "Downloads and installs update"
        case .remindLater:
            return "Reminds later"
        case .skipVersion:
            return "Skips this version"
        case .installAndRelaunch:
            return "Installs and relaunches"
        case .none:
            return nil
        }
    }

    private func onboardingDetailLabel(for step: OnboardingStep?) -> String? {
        guard let step else {
            return nil
        }

        return "Onboarding step: \(step.rawValue)"
    }

    private func questionActionsDetailLabel(for selectionCount: Int) -> String? {
        guard selectionCount > 0 else {
            return nil
        }

        return selectionCount == 1
            ? "1 selected question"
            : "\(selectionCount) selected questions"
    }

    private func focusedSessionDetailLabel(for item: IslandSurfaceRenderItem) -> String? {
        switch item.section {
        case .expandedPanel, .sessionCards, .switcher:
            guard let focusedSessionId = item.focusedSessionId else {
                return nil
            }

            return "Focused session: \(focusedSessionId)"
        case .compactPill, .notificationPeek, .usageInfo, .updatePill,
             .onboardingGlow, .questionActions, .actionRequests:
            return nil
        }
    }

    private func usageInfoDetailLabel(for infoBar: UsageInfoBar?) -> String? {
        guard let infoBar else {
            return nil
        }

        let textParts = [infoBar.primaryText, infoBar.secondaryText].compactMap { $0 }
        guard !textParts.isEmpty else {
            return infoBar.title.isEmpty ? nil : infoBar.title
        }

        guard !infoBar.title.isEmpty else {
            return textParts.joined(separator: " - ")
        }

        return "\(infoBar.title): \(textParts.joined(separator: " - "))"
    }

    private func compactPillDetailLabel(for rightSlotContent: PillRightSlotContent) -> String? {
        switch rightSlotContent {
        case let .usageRing(badge):
            if let percent = badge.percent {
                return "\(badge.providerDisplayName) usage: \(badge.title) (\(formatPercent(percent))%)"
            }

            return "\(badge.providerDisplayName) usage: \(badge.title)"
        case let .unreadCompletion(count):
            return count == 1 ? "1 unread completion" : "\(count) unread completions"
        case let .waitingAction(count):
            return count == 1 ? "1 waiting action" : "\(count) waiting actions"
        case let .activeCount(count):
            return count == 1 ? "1 active session" : "\(count) active sessions"
        case .none:
            return nil
        }
    }

    private func formatPercent(_ percent: Double) -> String {
        if percent.rounded() == percent {
            return String(Int(percent))
        }

        return String(percent)
    }

    private func accessibilityLabel(
        for section: IslandSurfaceSection,
        sections: IslandSurfaceSections
    ) -> String {
        switch section {
        case .compactPill:
            return "Compact island"
        case .expandedPanel:
            return "Expanded island panel"
        case .sessionCards:
            return "Session cards"
        case .notificationPeek:
            return "Notification peek"
        case .usageInfo:
            return "Usage information"
        case .updatePill:
            return sections.updatePill.label.isEmpty ? "Update" : sections.updatePill.label
        case .switcher:
            return "Session switcher"
        case .onboardingGlow:
            return "Onboarding highlight"
        case .questionActions:
            return "Question actions"
        case .actionRequests:
            return "Pending action requests"
        }
    }
}
