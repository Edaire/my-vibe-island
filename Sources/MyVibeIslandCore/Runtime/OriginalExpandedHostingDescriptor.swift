import Foundation

public struct OriginalExpandedSessionRow: Equatable, Sendable {
    public let session: AgentSession
    public let preview: SessionCardPreview
    public let status: OriginalPixelStatusCompact
    public let modelLabel: String?
    public let repositoryLabel: String?
    public let manuallyExpanded: Bool?
    public let statusWarning: Bool?
    public let dateAtOffset24: Date?
    public let taskSummary: String?
    public let todoSummary: String?
    public let childAgentSummary: String?

    public var id: String { preview.sessionId }

    public var expandedDisplayTitle: String {
        preview.displayTitle
    }

    public init(
        preview: SessionCardPreview,
        status: OriginalPixelStatusCompact = .unknown,
        modelLabel: String? = nil,
        repositoryLabel: String? = nil,
        manuallyExpanded: Bool? = nil,
        statusWarning: Bool? = nil,
        dateAtOffset24: Date? = nil,
        taskSummary: String? = nil,
        todoSummary: String? = nil,
        childAgentSummary: String? = nil
    ) {
        self.session = AgentSession(
            id: preview.sessionId,
            source: preview.sourceBadge,
            cwd: preview.localCwdDisplay,
            activeTool: preview.activeTool,
            activitySummary: preview.activitySummary,
            safeTitle: preview.displayTitle,
            originalStatus: status,
            pendingRequestIds: [],
            isRestored: preview.restored,
            isRemote: preview.isRemote,
            hasUnreadCompletion: preview.unreadCompletionMarker,
            jumpInput: nil,
            redactionLevel: preview.redactionLevel
        )
        self.preview = preview
        self.status = status
        self.modelLabel = modelLabel
        self.repositoryLabel = repositoryLabel
        self.manuallyExpanded = manuallyExpanded
        self.statusWarning = statusWarning
        self.dateAtOffset24 = dateAtOffset24
        self.taskSummary = taskSummary
        self.todoSummary = todoSummary
        self.childAgentSummary = childAgentSummary
    }

    public init(
        session: AgentSession,
        preview: SessionCardPreview? = nil,
        status: OriginalPixelStatusCompact? = nil,
        modelLabel: String? = nil,
        repositoryLabel: String? = nil,
        manuallyExpanded: Bool? = nil,
        statusWarning: Bool? = nil,
        dateAtOffset24: Date? = nil,
        taskSummary: String? = nil,
        todoSummary: String? = nil,
        childAgentSummary: String? = nil
    ) {
        self.session = session
        self.preview = preview ?? SessionCardPreview(session: session)
        self.status = status ?? session.originalStatus
        self.modelLabel = modelLabel ?? session.model
        self.repositoryLabel = repositoryLabel ?? session.repoName
        self.manuallyExpanded = manuallyExpanded
        self.statusWarning = statusWarning
        self.dateAtOffset24 = dateAtOffset24
        self.taskSummary = taskSummary
            ?? (session.tasks.isEmpty ? nil : "\(session.tasks.filter { $0.status == .active }.count)/\(session.tasks.count) active tasks")
        self.todoSummary = todoSummary
            ?? (session.todos.isEmpty ? nil : "\(session.todos.count) todos")
        self.childAgentSummary = childAgentSummary
            ?? (session.subagents.isEmpty ? nil : "\(session.subagents.count) subagents")
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }
}

public enum OriginalExpandedNonCommercialMeasurement {
    public static let cardHeight = 68.0
    public static let stackSpacing = 4.0
    public static let wrapperVerticalPadding = 8.0
    public static let listTopPadding = 4.0
    public static let listBottomPadding = 6.0

    /// The isolated V3 Codex approval capture measures a 640 x 236 surface.
    /// Geometry contributes 40pt of vertical chrome, leaving a 196pt content
    /// viewport for the approval card and session disclosure row.
    public static let collapsedPermissionContentHeight = 196.0

    public static func measuredContentHeight(sessionCount: Int) -> Double {
        let visibleCount = min(max(sessionCount, 0), 4)
        let cards = Double(visibleCount) * cardHeight
        let gaps = Double(max(visibleCount - 1, 0)) * stackSpacing
        let measured = listTopPadding
            + listBottomPadding
            + wrapperVerticalPadding
            + cards
            + gaps
        return max(84, measured)
    }
}

public struct OriginalExpandedContentPlan: Equatable, Sendable {
    public let sessionRows: [OriginalExpandedSessionRow]
    public let highlightedID: String?

    public static let empty = Self()

    public var displayRows: [OriginalExpandedSessionRow] {
        let highlighted = highlightedID.flatMap { id in
            sessionRows.first { $0.id == id }
        }
        return [highlighted].compactMap { $0 } + sessionRows.filter { $0.id != highlighted?.id }
    }

    public var completionBodyRowID: String? {
        highlightedID.flatMap { highlightedID in
            displayRows.first { $0.id == highlightedID }?.id
        } ?? displayRows.first?.id
    }

    public init(
        sessionRows: [OriginalExpandedSessionRow] = [],
        highlightedID: String? = nil
    ) {
        self.sessionRows = sessionRows
        self.highlightedID = highlightedID
    }
}

public struct OriginalExpandedHostingDescriptor: Equatable, Sendable {

    public let geometry: OriginalIslandGeometry
    public let rootLayoutPlan: OriginalRootSurfaceLayoutPlan
    public let contentPlan: OriginalExpandedContentPlan
    public let completionPreviewRow: OriginalExpandedSessionRow?
    public let usageInfoBar: UsageInfoBar?
    public let showsAllSessionRows: Bool

    public var surfaceSize: DisplaySize { geometry.surfaceSize }
    public var hostSize: DisplaySize { OriginalIslandGeometryResolver.panelSize }

    init(
        geometry: OriginalIslandGeometry,
        rootLayoutPlan: OriginalRootSurfaceLayoutPlan,
        contentPlan: OriginalExpandedContentPlan = .empty,
        completionPreviewRow: OriginalExpandedSessionRow? = nil,
        usageInfoBar: UsageInfoBar? = nil,
        showsAllSessionRows: Bool = false
    ) {
        self.geometry = geometry
        self.rootLayoutPlan = rootLayoutPlan
        self.contentPlan = contentPlan
        self.completionPreviewRow = completionPreviewRow
        self.usageInfoBar = usageInfoBar
        self.showsAllSessionRows = showsAllSessionRows
    }
}

public enum OriginalExpandedHostingDescriptorBuilder {
    public static func makeDescriptor(
        from input: OriginalIslandGeometryInput,
        contentPlan: OriginalExpandedContentPlan = .empty,
        completionPreviewRow: OriginalExpandedSessionRow? = nil,
        usageInfoBar: UsageInfoBar? = nil,
        showsAllSessionRows: Bool = false
    ) -> OriginalExpandedHostingDescriptor? {
        guard input.displayState == .expanded,
              input.maxExpandedWidth > 0,
              input.maxExpandedHeight > 0,
              input.maxExpandedWidth <= 640,
              input.maxExpandedHeight <= 560
        else {
            return nil
        }

        let geometry = OriginalIslandGeometryResolver().resolve(input)
        return OriginalExpandedHostingDescriptor(
            geometry: geometry,
            rootLayoutPlan: OriginalRootSurfaceLayoutPlan.resolve(
                displayState: .expanded,
                isHovering: false,
                safeAreaTopInset: input.safeAreaTopInset,
                leftStatusSlotWidth: input.leftStatusSlotWidth,
                rightStatusSlotWidth: input.rightStatusSlotWidth
            ),
            contentPlan: contentPlan,
            completionPreviewRow: completionPreviewRow,
            usageInfoBar: usageInfoBar,
            showsAllSessionRows: showsAllSessionRows
        )
    }
}
