import Foundation

public struct BehaviourSettings: Codable, Equatable, Sendable {
    public let childAgentNotificationTiming: V3RootResponseNotificationMode
    public let showSubagents: Bool
    public let hoverToExpandEnabled: Bool
    public let hoverExpandDelay: Double
    public let autoCollapseOnMouseLeave: Bool
    public let autoHideWhenIdle: Bool
    public let transientRevealDwellSeconds: Double
    public let dismissTransientRevealOnOutsideClick: Bool
    public let autoExpandOnTaskComplete: Bool
    public let autoExpandOnAgentTeamComplete: Bool
    public let disableClickToJump: Bool

    public var mouseLeaveCollapseDelay: Double { 0.25 }

    public init(
        childAgentNotificationTiming: V3RootResponseNotificationMode = .rootResponse,
        showSubagents: Bool = true,
        hoverToExpandEnabled: Bool = true,
        hoverExpandDelay: Double = 0.15,
        autoCollapseOnMouseLeave: Bool = true,
        autoHideWhenIdle: Bool = false,
        transientRevealDwellSeconds: Double = 5.0,
        dismissTransientRevealOnOutsideClick: Bool = false,
        autoExpandOnTaskComplete: Bool = true,
        autoExpandOnAgentTeamComplete: Bool = false,
        disableClickToJump: Bool = false
    ) {
        self.childAgentNotificationTiming = childAgentNotificationTiming
        self.showSubagents = showSubagents
        self.hoverToExpandEnabled = hoverToExpandEnabled
        self.hoverExpandDelay = min(max(hoverExpandDelay, 0.0), 5.0)
        self.autoCollapseOnMouseLeave = autoCollapseOnMouseLeave
        self.autoHideWhenIdle = autoHideWhenIdle
        self.transientRevealDwellSeconds = min(max(transientRevealDwellSeconds, 0.0), 30.0)
        self.dismissTransientRevealOnOutsideClick = dismissTransientRevealOnOutsideClick
        self.autoExpandOnTaskComplete = autoExpandOnTaskComplete
        self.autoExpandOnAgentTeamComplete = autoExpandOnAgentTeamComplete
        self.disableClickToJump = disableClickToJump
    }

    public func withAutomaticRevealsEnabled(_ isEnabled: Bool) -> BehaviourSettings {
        BehaviourSettings(
            childAgentNotificationTiming: childAgentNotificationTiming,
            showSubagents: showSubagents,
            hoverToExpandEnabled: hoverToExpandEnabled,
            hoverExpandDelay: hoverExpandDelay,
            autoCollapseOnMouseLeave: autoCollapseOnMouseLeave,
            autoHideWhenIdle: autoHideWhenIdle,
            transientRevealDwellSeconds: transientRevealDwellSeconds,
            dismissTransientRevealOnOutsideClick: dismissTransientRevealOnOutsideClick,
            autoExpandOnTaskComplete: isEnabled,
            autoExpandOnAgentTeamComplete: isEnabled,
            disableClickToJump: disableClickToJump
        )
    }

    private enum CodingKeys: String, CodingKey {
        case childAgentNotificationTiming
        case showSubagents
        case hoverToExpandEnabled
        case hoverExpandDelay
        case autoCollapseOnMouseLeave
        case autoHideWhenIdle
        case transientRevealDwellSeconds
        case dismissTransientRevealOnOutsideClick
        case autoExpandOnTaskComplete
        case autoExpandOnAgentTeamComplete
        case disableClickToJump
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            childAgentNotificationTiming: try container.decodeIfPresent(
                V3RootResponseNotificationMode.self,
                forKey: .childAgentNotificationTiming
            ) ?? .rootResponse,
            showSubagents: try container.decodeIfPresent(Bool.self, forKey: .showSubagents) ?? true,
            hoverToExpandEnabled: try container.decodeIfPresent(Bool.self, forKey: .hoverToExpandEnabled) ?? true,
            hoverExpandDelay: try container.decodeIfPresent(Double.self, forKey: .hoverExpandDelay) ?? 0.15,
            autoCollapseOnMouseLeave: try container.decodeIfPresent(Bool.self, forKey: .autoCollapseOnMouseLeave) ?? true,
            autoHideWhenIdle: try container.decodeIfPresent(Bool.self, forKey: .autoHideWhenIdle) ?? false,
            transientRevealDwellSeconds: try container.decodeIfPresent(Double.self, forKey: .transientRevealDwellSeconds) ?? 5.0,
            dismissTransientRevealOnOutsideClick: try container.decodeIfPresent(Bool.self, forKey: .dismissTransientRevealOnOutsideClick) ?? false,
            autoExpandOnTaskComplete: try container.decodeIfPresent(Bool.self, forKey: .autoExpandOnTaskComplete) ?? true,
            autoExpandOnAgentTeamComplete: try container.decodeIfPresent(Bool.self, forKey: .autoExpandOnAgentTeamComplete) ?? false,
            disableClickToJump: try container.decodeIfPresent(Bool.self, forKey: .disableClickToJump) ?? false
        )
    }
}
