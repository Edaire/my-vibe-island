import MyVibeIslandCore
import SwiftUI

struct OriginalExpandedSessionCardActions {
    let onSelectSession: (String) -> Void
    let onJumpToSession: (String) -> Void
    let onToggleManualExpansion: (String) -> Void

    init(
        onSelectSession: @escaping (String) -> Void,
        onJumpToSession: @escaping (String) -> Void,
        onToggleManualExpansion: @escaping (String) -> Void = { _ in }
    ) {
        self.onSelectSession = onSelectSession
        self.onJumpToSession = onJumpToSession
        self.onToggleManualExpansion = onToggleManualExpansion
    }

    func select(_ sessionID: String) { onSelectSession(sessionID) }
    func jump(_ sessionID: String) { onJumpToSession(sessionID) }
    func toggleManualExpansion(_ sessionID: String) { onToggleManualExpansion(sessionID) }

    func perform(_ action: OriginalExpandedSessionCardTapAction, sessionID: String) {
        switch action {
        case .select: select(sessionID)
        case .jump: jump(sessionID)
        case .toggleManualExpansion: toggleManualExpansion(sessionID)
        }
    }
}

enum OriginalExpandedSessionCardTapAction: Equatable {
    case select
    case jump
    case toggleManualExpansion

    static func resolve(manualExpansionEligible: Bool, jumpAvailable: Bool) -> Self {
        if manualExpansionEligible {
            return .toggleManualExpansion
        }
        return jumpAvailable ? .jump : .select
    }

    static func resolve(jumpAvailable: Bool) -> Self {
        resolve(manualExpansionEligible: false, jumpAvailable: jumpAvailable)
    }
}

enum OriginalExpandedSessionCardTapMotion: Equatable {
    case none
    case easeInOut(duration: Double)

    static func resolve(for action: OriginalExpandedSessionCardTapAction) -> Self {
        switch action {
        case .toggleManualExpansion:
            return .easeInOut(duration: 0.2)
        case .select, .jump:
            return .none
        }
    }
}

enum OriginalExpandedCompletionBodyPlan {
    static func shouldRender(
        isMounted: Bool,
        status: OriginalPixelStatusCompact,
        hasUnreadCompletion: Bool,
        assistantMessage: String?
    ) -> Bool {
        guard isMounted else { return false }
        guard hasUnreadCompletion else { return false }
        return assistantMessage?.contains(where: { !$0.isWhitespace }) == true
    }
}

struct OriginalExpandedAssistantScrollView: View {
    let message: String
    let maximumHeight: Double
    @AppStorage("contentFontSize") private var contentFontSize = 11.0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(message)
                .font(.system(size: contentFontSize, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(8)
        }
        .scrollIndicators(.automatic)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: CGFloat(min(max(maximumHeight, 80), 400)))
    }
}

struct OriginalExpandedSessionCardView: View {
    private let layout = OriginalExpandedSessionLayoutPlan.original
    let row: OriginalExpandedSessionRow
    let actionRequests: [ActionRequestPreview]
    let derivedCollectionCount: Int
    let isFirst: Bool?
    let isHighlighted: Bool
    let mountsCompletionBody: Bool
    let reservesHeaderControls: Bool
    let actions: OriginalExpandedSessionCardActions
    let onSubmitActionResolution: (ActionResolution) -> Bool
    @AppStorage("showModelInPanel") private var showModelInPanel = false
    @AppStorage("hideAgentDetailLine") private var hideAgentDetailLine = false
    @AppStorage("contentFontSize") private var contentFontSize = 11.0
    @AppStorage("completionCardMaxHeight") private var completionCardMaxHeight = 90.0
    @State private var isHovered = false
    @State private var isApprovalHovered = false
    @State private var requestCollectionState: OriginalExpandedActionRequestCollectionState

    init(
        row: OriginalExpandedSessionRow,
        actionRequests: [ActionRequestPreview] = [],
        derivedCollectionCount: Int = 0,
        isFirst: Bool? = nil,
        isHighlighted: Bool,
        mountsCompletionBody: Bool = false,
        reservesHeaderControls: Bool = false,
        onSelectSession: @escaping (String) -> Void = { _ in },
        onJumpToSession: @escaping (String) -> Void = { _ in },
        onToggleManualExpansion: @escaping (String) -> Void = { _ in },
        onSubmitActionResolution: @escaping (ActionResolution) -> Bool = { _ in false }
    ) {
        self.row = row
        self.actionRequests = actionRequests
        self.derivedCollectionCount = derivedCollectionCount
        self.isFirst = isFirst
        self.isHighlighted = isHighlighted
        self.mountsCompletionBody = mountsCompletionBody
        self.reservesHeaderControls = reservesHeaderControls
        actions = OriginalExpandedSessionCardActions(
            onSelectSession: onSelectSession,
            onJumpToSession: onJumpToSession,
            onToggleManualExpansion: onToggleManualExpansion
        )
        self.onSubmitActionResolution = onSubmitActionResolution
        _requestCollectionState = State(initialValue: OriginalExpandedActionRequestCollectionState(
            requestIDs: actionRequests.map(\.requestId)
        ))
    }

    var body: some View {
        VStack(spacing: 4) {
            branchShell
                .frame(minHeight: CGFloat(OriginalExpandedNonCommercialMeasurement.cardHeight))
                .contentShape(Rectangle())
                .onTapGesture {
                    performTapAction()
                }
                .contextMenu {
                    if !row.session.cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            V3SilenceRulesPreferenceStore().addCustomRule(
                                field: .cwd,
                                matchType: .contains,
                                pattern: row.session.cwd
                            )
                        } label: {
                            Text("Hide sessions in this directory\n\(row.session.cwd)")
                        }
                    }
                    if let firstUserMessage = row.session.firstUserMessage,
                       let prompt = contextMenuPrompt(firstUserMessage) {
                        Button {
                            V3SilenceRulesPreferenceStore().addCustomRule(
                                field: .firstUserPrompt,
                                matchType: .prefix,
                                pattern: firstUserMessage
                            )
                        } label: {
                            Text("Silence prompts starting with…\n\(prompt)")
                        }
                    }
                }
            actionSurface
        }
        .id(row.id)
        .onChange(of: actionRequests.map(\.requestId), initial: true) { _, requestIDs in
            requestCollectionState = requestCollectionState.replacingRequestIDs(requestIDs)
        }
    }

    private func contextMenuPrompt(_ message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 7 else { return nil }
        return String(trimmed.prefix(40))
    }

    @ViewBuilder
    private var branchShell: some View {
        switch branchAxis {
        case .horizontal:
            let decision = OriginalSessionCardHorizontalVisualDecision.resolve(
                isHovered: isHovered,
                cardID: row.id,
                highlightedID: isHighlighted ? row.id : nil
            )
            OriginalExpandedSessionCardSurface(
                plan: .horizontalBranch,
                fill: decision.fill,
                stroke: decision.stroke,
                animationValue: decision.animationValue
            ) {
                let header = OriginalExpandedSessionHeaderDescriptor.resolve(row: row)
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                    title
                    Spacer(minLength: 0)
                    headerBadge(header.sourceLabel, placeholder: "Codex")
                    headerBadge(header.terminalLabel, placeholder: "tmux")
                    headerBadge(header.ageLabel, placeholder: "000m")
                }
            }
            .onHover { isHovering in
                isHovered = isHovering
            }
        case .vertical:
            let decision = OriginalSessionCardVerticalVisualDecision.resolve(
                isHovered: isHovered,
                isApprovalHovered: isApprovalHovered,
                cardID: row.id,
                highlightedID: isHighlighted ? row.id : nil
            )
            OriginalExpandedSessionCardSurface(
                plan: .verticalBranch,
                fill: decision.fill,
                stroke: decision.stroke,
                animationValue: decision.animationValue
            ) {
                verticalBody
            }
            .onHover { isHovering in
                isHovered = isHovering
            }
        }
    }

    private var branchAxis: OriginalSessionCardShellPlan.Axis {
        OriginalSessionCardBranchSelector.resolve(
            derivedCollectionCount: derivedCollectionCount,
            manuallyExpanded: row.manuallyExpanded,
            statusWarning: row.statusWarning,
            isFirst: isFirst,
            dateAtOffset24: row.dateAtOffset24,
            now: Date(),
            isCompletionPreview: mountsCompletionBody
        )
    }

    private func performTapAction() {
        let preview = SessionCardPreview(session: row.session)
        let action = OriginalExpandedSessionCardTapAction.resolve(
            manualExpansionEligible: branchAxis == .horizontal,
            jumpAvailable: preview.jumpAvailable
        )
        switch OriginalExpandedSessionCardTapMotion.resolve(for: action) {
        case .none:
            actions.perform(action, sessionID: row.id)
        case let .easeInOut(duration):
            withAnimation(.easeInOut(duration: duration)) {
                actions.perform(action, sessionID: row.id)
            }
        }
    }

    private var verticalBody: some View {
        let presentation = OriginalExpandedSessionCardPresentation.resolve(row: row)
        return VStack(alignment: .center, spacing: selectedPermissionRequest == nil ? 8 : 5) {
            HStack(alignment: .center, spacing: CGFloat(layout.columnSpacing)) {
                statusIcon(status: presentation.body.status)
                VStack(alignment: .leading, spacing: CGFloat(layout.contentSpacing)) {
                    sessionHeader(presentation: presentation)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let permissionRequest = selectedPermissionRequest {
                OriginalExpandedPermissionRequestCard(
                    request: permissionRequest,
                    onJumpToTerminal: { actions.jump(row.id) },
                    onSubmit: onSubmitActionResolution,
                    onApprovalHoverChange: { isHovering in
                        isApprovalHovered = isHovering
                    }
                )
            } else if shouldRenderCompletionBody {
                completionBodyCard(presentation: presentation).padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func completionBodyCard(
        presentation: OriginalExpandedSessionCardPresentation
    ) -> some View {
        if let assistantMessage = presentation.completionAssistantMessage {
            OriginalCompletionCardView {
                completionHeader(presentation: presentation)
            } viewport: {
                OriginalExpandedAssistantScrollView(
                    message: assistantMessage,
                    maximumHeight: completionCardMaxHeight
                )
            }
        }
    }

    private func statusIcon(status: OriginalPixelStatusCompact) -> some View {
        OriginalPixelStatusIconView(status: status)
            .frame(width: CGFloat(layout.statusWidth), height: CGFloat(layout.statusHeight))
    }

    private func completionStatusColumn(status: OriginalPixelStatusCompact) -> some View {
        Button { actions.select(row.id) } label: {
            statusIcon(status: status)
                .frame(width: CGFloat(layout.statusWidth))
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select session")
    }

    private func completionHeader(
        presentation: OriginalExpandedSessionCardPresentation
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if let prompt = presentation.header.prompt {
                Text("你：")
                    .font(.system(size: contentFontSize, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                Text(prompt)
                    .font(.system(size: contentFontSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Text("完成")
                .font(.system(size: contentFontSize, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.62))
        }
    }

    private func sessionHeader(
        presentation: OriginalExpandedSessionCardPresentation
    ) -> some View {
        let descriptor = presentation.body
        let header = presentation.header

        return VStack(alignment: .leading, spacing: CGFloat(layout.contentSpacing)) {
            HStack(alignment: .center, spacing: CGFloat(layout.columnSpacing)) {
                Text(header.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                headerBadge(header.sourceLabel, placeholder: "Codex")
                headerBadge(header.terminalLabel, placeholder: "tmux")
                headerBadge(header.ageLabel, placeholder: "000m")
                if presentation.jumpAvailable {
                    headerJumpControl(sessionID: row.id)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let prompt = header.prompt {
                        Text("你：\(prompt)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            if selectedPermissionRequest == nil, !hideAgentDetailLine {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let activityToolLabel = descriptor.activityToolLabel {
                        Text(activityToolLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.blue.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let activityContent = descriptor.activityContent ?? descriptor.activityLine,
                       activityContent != descriptor.activityToolLabel {
                        Text(activityContent)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                }
            }
            if selectedPermissionRequest == nil, let approvalSummary = descriptor.approvalSummary {
                Text(approvalSummary)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let details = descriptor.passiveQuestionDetails {
                passiveQuestionDetailsView(details)
            } else if let questionPrompt = descriptor.questionPrompt {
                Text(questionPrompt)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func passiveQuestionDetailsView(_ details: ActionRequestDetails) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if details.questions.isEmpty {
                if let prompt = details.prompt {
                    Text(prompt)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                }
                passiveOptionLabels(details.options)
            } else {
                ForEach(Array(details.questions.enumerated()), id: \.offset) { _, question in
                    if !question.header.isEmpty {
                        Text(question.header)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.58))
                    }
                    Text(question.prompt)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                    passiveOptionLabels(question.options)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func passiveOptionLabels(_ options: [ActionRequestOption]) -> some View {
        if !options.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text("• \(option.label)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
    }

    private var shouldRenderCompletionBody: Bool {
        let presentation = OriginalExpandedSessionCardPresentation.resolve(row: row)
        return OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: mountsCompletionBody,
            status: row.status,
            hasUnreadCompletion: presentation.hasUnreadCompletion,
            assistantMessage: presentation.completionAssistantMessage
        )
    }

    @ViewBuilder
    private func headerBadge(_ value: String?, placeholder: String) -> some View {
        ZStack {
            headerBadgeText(placeholder).hidden()
            if let value {
                headerBadgeText(value)
            }
        }
    }

    private func headerBadgeText(_ value: String) -> some View {
        OriginalTagPill(value: value)
    }

    private func headerJumpControl(sessionID: String) -> some View {
        OriginalExpandedHeaderJumpControl {
            actions.jump(sessionID)
        }
    }

    @ViewBuilder
    private var actionSurface: some View {
        if actionRequests.count > 1 {
            HStack(spacing: 6) {
                ForEach(actionRequests, id: \.requestId) { request in
                    Button(request.toolName) {
                        requestCollectionState = requestCollectionState.selecting(request.requestId)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if let request = selectedActionRequest, request.kind != .permission {
            OriginalExpandedActionRequestView(
                request: request,
                onSubmit: onSubmitActionResolution
            )
            .id(request.requestId)
        }
    }

    private var selectedActionRequest: ActionRequestPreview? {
        guard let selectedRequestID = requestCollectionState.selectedRequestID else { return nil }
        return actionRequests.first { $0.requestId == selectedRequestID }
    }

    private var selectedPermissionRequest: ActionRequestPreview? {
        actionRequests.first { $0.kind == .permission }
    }

    private var title: some View {
        let plan = OriginalSessionCardHorizontalTitlePlan.resolve(
            baseTitle: row.preview.displayTitle,
            showModelInPanel: showModelInPanel,
            modelLabel: row.modelLabel,
            repositoryLabel: row.repositoryLabel
        )
        return plan.segments.reduce(Text("")) { result, segment in
            result + Text(segment.prefix + segment.value)
                .foregroundStyle(segment.foreground.map(titleColor) ?? titleColor(plan.foreground))
        }
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .truncationMode(.tail)
        .layoutPriority(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func titleColor(_ value: OriginalSessionCardHorizontalTitlePlan.Color) -> Color {
        switch value { case let .white(opacity): return Color.white.opacity(opacity) }
    }
}
