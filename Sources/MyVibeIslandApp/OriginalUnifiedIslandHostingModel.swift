import Combine
import MyVibeIslandCore

public enum OriginalUnifiedIslandPresentation: Equatable {
    case compact(OriginalCompactHostingDescriptor)
    case peek(
        compact: OriginalCompactHostingDescriptor,
        descriptor: OriginalPeekHostingDescriptor,
        state: OriginalPeekDisplayState
    )
    case expanded(OriginalExpandedHostingDescriptor)
    case switcher(OriginalSwitcherHostingDescriptor)

    public var displayState: OriginalIslandDisplayState {
        switch self {
        case .compact:
            return .compact
        case .peek:
            return .peek
        case .expanded:
            return .expanded
        case .switcher:
            return .expanded
        }
    }
}

public struct OriginalUnifiedIslandRootAnimationInputs: Equatable, Sendable {
    public let isMinimized: Bool
    public let isHovering: Bool
    public let layoutMode: NotchLayoutMode
    public let notchHeightOffset: Double
    public let completionFlashTick: Int

    public init(
        isMinimized: Bool,
        isHovering: Bool,
        layoutMode: NotchLayoutMode,
        notchHeightOffset: Double,
        completionFlashTick: Int = 0
    ) {
        self.isMinimized = isMinimized
        self.isHovering = isHovering
        self.layoutMode = layoutMode
        self.notchHeightOffset = notchHeightOffset
        self.completionFlashTick = completionFlashTick
    }
}

@MainActor
public final class OriginalUnifiedIslandHostingModel: ObservableObject {
    @Published public private(set) var presentation: OriginalUnifiedIslandPresentation
    @Published public private(set) var rootIsMinimized: Bool
    @Published public private(set) var rootIsHovering: Bool
    @Published public private(set) var rootLayoutMode: NotchLayoutMode
    @Published public private(set) var rootNotchHeightOffset: Double
    @Published public private(set) var completionFlashTick: Int
    @Published public private(set) var selectedSessionID: String?
    @Published public private(set) var actionRequests: [ActionRequestPreview]

    public init(
        presentation: OriginalUnifiedIslandPresentation,
        actionRequests: [ActionRequestPreview] = [],
        rootAnimationInputs: OriginalUnifiedIslandRootAnimationInputs? = nil
    ) {
        self.presentation = presentation
        let rootInputs = rootAnimationInputs ?? Self.rootAnimationInputs(for: presentation)
        self.rootIsMinimized = rootInputs.isMinimized
        self.rootIsHovering = rootInputs.isHovering
        self.rootLayoutMode = rootInputs.layoutMode
        self.rootNotchHeightOffset = rootInputs.notchHeightOffset
        self.completionFlashTick = rootInputs.completionFlashTick
        self.selectedSessionID = nil
        self.actionRequests = actionRequests
    }

    @discardableResult
    public func replace(
        _ presentation: OriginalUnifiedIslandPresentation,
        rootAnimationInputs: OriginalUnifiedIslandRootAnimationInputs? = nil
    ) -> Bool {
        let rootInputs = rootAnimationInputs ?? Self.rootAnimationInputs(for: presentation)
        guard self.presentation != presentation
            || rootIsMinimized != rootInputs.isMinimized
            || rootIsHovering != rootInputs.isHovering
            || rootLayoutMode != rootInputs.layoutMode
            || rootNotchHeightOffset != rootInputs.notchHeightOffset
            || completionFlashTick != rootInputs.completionFlashTick
        else {
            return false
        }

        self.presentation = presentation
        rootIsMinimized = rootInputs.isMinimized
        rootIsHovering = rootInputs.isHovering
        rootLayoutMode = rootInputs.layoutMode
        rootNotchHeightOffset = rootInputs.notchHeightOffset
        completionFlashTick = rootInputs.completionFlashTick
        return true
    }

    public func selectSession(_ sessionID: String) {
        selectedSessionID = sessionID
    }

    public func replaceActionRequests(_ requests: [ActionRequestPreview]) {
        guard requests != actionRequests else { return }
        actionRequests = requests
    }

    private static func rootAnimationInputs(
        for presentation: OriginalUnifiedIslandPresentation
    ) -> OriginalUnifiedIslandRootAnimationInputs {
        switch presentation {
        case let .compact(descriptor):
            OriginalUnifiedIslandRootAnimationInputs(
                isMinimized: descriptor.isMinimized,
                isHovering: descriptor.isHovering,
                layoutMode: descriptor.layoutMode == .compact ? .compact : .regular,
                notchHeightOffset: descriptor.rootNotchHeightOffset,
                completionFlashTick: descriptor.completionFlashTick
            )
        case let .peek(compact, _, _):
            OriginalUnifiedIslandRootAnimationInputs(
                isMinimized: compact.isMinimized,
                isHovering: compact.isHovering,
                layoutMode: compact.layoutMode == .compact ? .compact : .regular,
                notchHeightOffset: compact.rootNotchHeightOffset,
                completionFlashTick: compact.completionFlashTick
            )
        case .expanded, .switcher:
            OriginalUnifiedIslandRootAnimationInputs(
                isMinimized: false,
                isHovering: false,
                layoutMode: .expanded,
                notchHeightOffset: 0
            )
        }
    }
}
