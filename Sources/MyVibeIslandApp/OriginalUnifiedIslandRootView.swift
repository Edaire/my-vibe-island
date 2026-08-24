import MyVibeIslandCore
import SwiftUI

public struct OriginalUnifiedIslandRootView: View {
    @ObservedObject public var model: OriginalUnifiedIslandHostingModel
    private let onExpandedContentHeightChange: (Double, [String]) -> Void
    private let onOpenSettings: () -> Void
    private let onContextMenuCommand: (AppCommand) -> Void
    private let onSelectSession: (String) -> Void
    private let onJumpToSession: (String) -> Void
    private let onToggleManualExpansion: (String) -> Void
    private let onNavigateSwitcher: (SwitcherNavigationDirection) -> Void
    private let onSubmitSwitcher: () -> Void
    private let onCollapseSwitcher: () -> Void
    private let onRequestFocus: () -> Void
    private let onReleaseFocus: () -> Void
    private let onExpandedContentHoverChange: (Bool) -> Void
    private let onSubmitActionResolution: (ActionResolution) -> Bool
    @AppStorage(SoundPreferencesStore.Key.isEnabled) private var soundEnabled = true
    @State private var appearScale: CGFloat = 0.1
    @State private var completionFlashProgress = 0.0
    private let onCompletionContentHeightChange: (Double, [String]) -> Void

    public init(
        model: OriginalUnifiedIslandHostingModel,
        onExpandedContentHeightChange: @escaping (Double, [String]) -> Void = { _, _ in },
        onOpenSettings: @escaping () -> Void = {},
        onContextMenuCommand: @escaping (AppCommand) -> Void = { _ in },
        onSelectSession: @escaping (String) -> Void = { _ in },
        onJumpToSession: @escaping (String) -> Void = { _ in },
        onToggleManualExpansion: @escaping (String) -> Void = { _ in },
        onNavigateSwitcher: @escaping (SwitcherNavigationDirection) -> Void = { _ in },
        onSubmitSwitcher: @escaping () -> Void = {},
        onCollapseSwitcher: @escaping () -> Void = {},
        onRequestFocus: @escaping () -> Void = {},
        onReleaseFocus: @escaping () -> Void = {},
        onExpandedContentHoverChange: @escaping (Bool) -> Void = { _ in },
        onCompletionContentHeightChange: @escaping (Double, [String]) -> Void = { _, _ in },
        onSubmitActionResolution: @escaping (ActionResolution) -> Bool = { _ in false }
    ) {
        self.model = model
        self.onExpandedContentHeightChange = onExpandedContentHeightChange
        self.onOpenSettings = onOpenSettings
        self.onContextMenuCommand = onContextMenuCommand
        self.onSelectSession = onSelectSession
        self.onJumpToSession = onJumpToSession
        self.onToggleManualExpansion = onToggleManualExpansion
        self.onNavigateSwitcher = onNavigateSwitcher
        self.onSubmitSwitcher = onSubmitSwitcher
        self.onCollapseSwitcher = onCollapseSwitcher
        self.onRequestFocus = onRequestFocus
        self.onReleaseFocus = onReleaseFocus
        self.onExpandedContentHoverChange = onExpandedContentHoverChange
        self.onCompletionContentHeightChange = onCompletionContentHeightChange
        self.onSubmitActionResolution = onSubmitActionResolution
    }

    public var surfaceSize: DisplaySize { model.presentation.fittingSize }

    public var visibleSurfaceSize: DisplaySize {
        model.presentation.visibleSurfaceSize
    }

    public var displayClass: OriginalCompactBaseLayoutPlan.DisplayClass? {
        guard case let .compact(descriptor) = model.presentation else { return nil }
        return descriptor.displayClass
    }

    public var layoutMode: OriginalNotchLayoutMode? {
        guard case let .compact(descriptor) = model.presentation else { return nil }
        return descriptor.layoutMode
    }

    public var body: some View {
        let presentation = model.presentation
        let layoutPlan = presentation.rootLayoutPlan
        let fittingSize = presentation.fittingSize
        let visibleSize = presentation.visibleSurfaceSize
        let animationContract = OriginalRootAnimationContract.resolve(
            displayState: presentation.displayState,
            fittingWidth: fittingSize.width,
            fittingHeight: fittingSize.height,
            visibleSurfaceHeight: visibleSize.height
        )

        return ZStack(alignment: .top) {
            Color.black
                .frame(
                    width: CGFloat(visibleSize.width),
                    height: CGFloat(visibleSize.height)
                )
                .clipShape(OriginalNotchShape(
                    topCornerRadius: CGFloat(layoutPlan.shape.topCornerRadius),
                    bottomCornerRadius: CGFloat(layoutPlan.shape.bottomCornerRadius)
                ))
                .background(alignment: .top) {
                    Color.black
                        .frame(
                            width: CGFloat(max(
                                0,
                                visibleSize.width - 2 * layoutPlan.topSeamHorizontalInset
                            )),
                            height: CGFloat(layoutPlan.topSeamHeight)
                        )
                }
                .shadow(
                    color: layoutPlan.shadow.colorKind == .clear
                        ? Color.clear
                        : Color.black.opacity(layoutPlan.shadow.opacity),
                    radius: CGFloat(layoutPlan.shadow.radius),
                    x: CGFloat(layoutPlan.shadow.x),
                    y: CGFloat(layoutPlan.shadow.y)
                )

            stateContent(presentation)
                .frame(
                    width: CGFloat(fittingSize.width),
                    height: CGFloat(fittingSize.height),
                    alignment: .top
                )
                .frame(
                    width: CGFloat(visibleSize.width),
                    height: CGFloat(visibleSize.height),
                    alignment: .top
                )
                .clipShape(OriginalNotchShape(
                    topCornerRadius: CGFloat(layoutPlan.shape.topCornerRadius),
                    bottomCornerRadius: CGFloat(layoutPlan.shape.bottomCornerRadius)
                ))
                .onHover(perform: onExpandedContentHoverChange)
        }
        .contextMenu {
            Button("Open Settings") {
                onContextMenuCommand(.openSettings)
            }
            Button("Check for Updates") {
                onContextMenuCommand(.checkForUpdates)
            }
            Divider()
            Button("Quit Vibe Island") {
                onContextMenuCommand(.quit)
            }
        }
        .animation(
            animation(for: animationContract.displayStatusCurve),
            value: animationContract.displayStatusTarget
        )
        .animation(
            animation(for: .expanded),
            value: animationContract.expandedWidthTarget
        )
        .animation(
            animation(for: .expanded),
            value: animationContract.expandedHeightTarget
        )
        .animation(
            animation(for: .expanded),
            value: animationContract.visibleSurfaceHeightTarget
        )
        .frame(
            width: CGFloat(fittingSize.width),
            height: CGFloat(fittingSize.height),
            alignment: .top
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: CGFloat(layoutPlan.physicalHorizontalOffset), y: 0)
        .scaleEffect(x: appearScale, y: 1, anchor: .center)
        .scaleEffect(layoutPlan.hoverScale, anchor: .center)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0),
            value: model.rootIsMinimized
        )
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0),
            value: model.rootLayoutMode
        )
        .animation(
            .spring(
                response: OriginalRootAnimationContract.rootHoverSpring.response,
                dampingFraction: OriginalRootAnimationContract.rootHoverSpring.dampingFraction,
                blendDuration: 0
            ),
            value: model.rootIsHovering
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                appearScale = 1
            }
        }
        .onChange(of: model.completionFlashTick, initial: false) { _, _ in
            guard model.presentation.displayState != .expanded else { return }
            completionFlashProgress = 0.9
            withAnimation(.easeOut(duration: 1.1)) {
                completionFlashProgress = 0
            }
        }
    }

    @ViewBuilder
    private func stateContent(_ presentation: OriginalUnifiedIslandPresentation) -> some View {
        switch presentation {
        case let .compact(descriptor):
            VStack(alignment: .center, spacing: CGFloat(descriptor.rootLayoutPlan.rootStackSpacing)) {
                OriginalCompactRowView(
                    displayClass: descriptor.displayClass,
                    contentPlan: descriptor.contentPlan,
                    layoutPlan: descriptor.compactLayoutPlan,
                    rightPresentationPlan: descriptor.rightPresentationPlan,
                    layoutMode: descriptor.layoutMode,
                    isMinimized: descriptor.isMinimized,
                    completionFlashProgress: completionFlashProgress
                )
            }
        case let .peek(compact, descriptor, state):
            VStack(alignment: .center, spacing: CGFloat(descriptor.rootLayoutPlan.rootStackSpacing)) {
                OriginalCompactRowView(
                    displayClass: compact.displayClass,
                    contentPlan: compact.contentPlan,
                    layoutPlan: compact.compactLayoutPlan,
                    rightPresentationPlan: compact.rightPresentationPlan,
                    layoutMode: compact.layoutMode,
                    isMinimized: compact.isMinimized,
                    completionFlashProgress: completionFlashProgress
                )

                OriginalPeekSupplementalView(state: state)
            }
        case let .expanded(descriptor):
            VStack(spacing: 0) {
                if descriptor.completionPreviewRow != nil {
                    expandedBaseBody(descriptor)
                        .padding(.horizontal, CGFloat(OriginalExpandedStatusTwoLayoutPlan.baseHorizontalInset))
                        .padding(.vertical, CGFloat(OriginalExpandedStatusTwoLayoutPlan.baseVerticalInset))
                } else {
                    expandedBaseBody(descriptor)
                        .padding(.horizontal, CGFloat(descriptor.rootLayoutPlan.outerHorizontalInset))
                        .padding(.bottom, CGFloat(descriptor.rootLayoutPlan.innerHorizontalBottomPadding))
                }

                if let completionPreviewRow = descriptor.completionPreviewRow {
                    OriginalExpandedSessionCardView(
                        row: completionPreviewRow,
                        actionRequests: model.actionRequests.filter {
                            $0.sessionId == completionPreviewRow.id
                        },
                        isHighlighted: false,
                        mountsCompletionBody: true,
                        reservesHeaderControls: false,
                        onSelectSession: { sessionID in
                            model.selectSession(sessionID)
                            onSelectSession(sessionID)
                        },
                        onJumpToSession: onJumpToSession,
                        onToggleManualExpansion: onToggleManualExpansion,
                        onSubmitActionResolution: onSubmitActionResolution
                    )
                    .padding(.horizontal, CGFloat(OriginalExpandedStatusTwoLayoutPlan.completionHorizontalInset))
                    .padding(.top, CGFloat(OriginalExpandedStatusTwoLayoutPlan.completionTopInset))
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: OriginalExpandedCompletionMeasuredHeightPreferenceKey.self,
                                value: Double(geometry.size.height)
                            )
                        }
                    }
                }
            }
            .onPreferenceChange(OriginalExpandedCompletionMeasuredHeightPreferenceKey.self) { measuredHeight in
                onCompletionContentHeightChange(
                    measuredHeight,
                    descriptor.contentPlan.displayRows.map(\.id)
                )
            }
        case let .switcher(descriptor):
            expandedBaseBody(
                contentPlan: descriptor.contentPlan,
                layoutPlan: descriptor.rootLayoutPlan,
                mountsCompletionBodies: true,
                usageInfoBar: nil
            )
            .focusable()
            .onMoveCommand { direction in
                switch direction {
                case .up:
                    onNavigateSwitcher(.up)
                case .down:
                    onNavigateSwitcher(.down)
                default:
                    break
                }
            }
            .onSubmit(onSubmitSwitcher)
            .onAppear(perform: onRequestFocus)
            .onDisappear(perform: onReleaseFocus)
        }
    }

    @ViewBuilder
    private func expandedBaseBody(_ descriptor: OriginalExpandedHostingDescriptor) -> some View {
        expandedBaseBody(
            contentPlan: descriptor.contentPlan,
            layoutPlan: descriptor.rootLayoutPlan,
            mountsCompletionBodies: descriptor.completionPreviewRow == nil,
            usageInfoBar: descriptor.usageInfoBar
        )
    }

    @ViewBuilder
    private func expandedBaseBody(
        contentPlan: OriginalExpandedContentPlan,
        layoutPlan: OriginalRootSurfaceLayoutPlan,
        mountsCompletionBodies: Bool,
        usageInfoBar: UsageInfoBar?
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            OriginalExpandedSessionsListView(
                contentPlan: contentPlan,
                layoutPlan: layoutPlan,
                actionRequests: model.actionRequests,
                mountsCompletionBodies: mountsCompletionBodies,
                viewportHeight: model.presentation.expandedSurfaceViewportHeight,
                onSelectSession: { sessionID in
                    model.selectSession(sessionID)
                    onSelectSession(sessionID)
                },
                onJumpToSession: onJumpToSession,
                onToggleManualExpansion: onToggleManualExpansion,
                onSubmitActionResolution: onSubmitActionResolution,
                onMeasuredHeightChange: { measuredHeight in
                    onExpandedContentHeightChange(
                        measuredHeight,
                        contentPlan.displayRows.map(\.id)
                    )
                }
            )

            OriginalExpandedHeaderControlsView(
                soundEnabled: soundEnabled,
                onToggleSound: { soundEnabled.toggle() },
                onOpenSettings: onOpenSettings
            )
            .padding(.top, 6)
            .padding(.trailing, 6)

            if let usageHeader = OriginalExpandedUsageWaitingHeaderPlan.resolve(
                usageInfoBar: usageInfoBar,
                rows: contentPlan.displayRows
            ) {
                OriginalExpandedUsageWaitingHeaderView(plan: usageHeader)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 12)
                    .padding(.leading, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private func animation(for curve: OriginalRootAnimationContract.Curve) -> Animation {
        switch curve {
        case .expanded:
            .spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
        case .nonExpanded:
            .spring(response: 0.45, dampingFraction: 1, blendDuration: 0)
        }
    }
}

private extension OriginalUnifiedIslandPresentation {
    var expandedSurfaceViewportHeight: Double? {
        guard case let .expanded(descriptor) = self else { return nil }
        return descriptor.surfaceSize.height
    }
}

private struct OriginalExpandedCompletionMeasuredHeightPreferenceKey: PreferenceKey {
    static let defaultValue = 0.0

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

private extension OriginalUnifiedIslandPresentation {
    var rootLayoutPlan: OriginalRootSurfaceLayoutPlan {
        switch self {
        case let .compact(descriptor):
            return descriptor.rootLayoutPlan
        case let .peek(_, descriptor, _):
            return descriptor.rootLayoutPlan
        case let .expanded(descriptor):
            return descriptor.rootLayoutPlan
        case let .switcher(descriptor):
            return descriptor.rootLayoutPlan
        }
    }

    var fittingSize: DisplaySize {
        switch self {
        case let .compact(descriptor):
            return descriptor.surfaceSize
        case let .peek(_, descriptor, _):
            return descriptor.surfaceSize
        case let .expanded(descriptor):
            return descriptor.surfaceSize
        case let .switcher(descriptor):
            return descriptor.surfaceSize
        }
    }

    var visibleSurfaceSize: DisplaySize {
        switch self {
        case let .compact(descriptor):
            let layoutPlan = descriptor.rootLayoutPlan
            return DisplaySize(
                width: descriptor.surfaceSize.width
                    + 2 * layoutPlan.outerHorizontalInset
                    + 2 * layoutPlan.innerHorizontalBottomPadding,
                height: descriptor.surfaceSize.height
            )
        case let .peek(_, descriptor, _):
            return descriptor.surfaceSize
        case let .expanded(descriptor):
            return descriptor.surfaceSize
        case let .switcher(descriptor):
            return descriptor.surfaceSize
        }
    }

    var completionFlashTick: Int {
        switch self {
        case let .compact(descriptor):
            return descriptor.completionFlashTick
        case let .peek(compact, _, _):
            return compact.completionFlashTick
        case .expanded:
            return 0
        case .switcher:
            return 0
        }
    }
}
