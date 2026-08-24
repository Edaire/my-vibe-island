import Foundation

public struct WhatsNewStoreState: Codable, Equatable, Sendable {
    public let pendingHTML: String?
    public let pendingVersion: String?
    public let pendingPreviousVersion: String?
    public let lastLaunchedVersion: String?

    public init(
        pendingHTML: String? = nil,
        pendingVersion: String? = nil,
        pendingPreviousVersion: String? = nil,
        lastLaunchedVersion: String? = nil
    ) {
        self.pendingHTML = pendingHTML
        self.pendingVersion = pendingVersion
        self.pendingPreviousVersion = pendingPreviousVersion
        self.lastLaunchedVersion = lastLaunchedVersion
    }
}

public enum WhatsNewStoreCommand: Equatable, Sendable {
    case recordLaunch(currentVersion: String, rawHTML: String?)
    case dismissPending
}

public enum WhatsNewStoreAction: String, Codable, Equatable, Sendable {
    case noChange
    case showWhatsNew
    case dismissWhatsNew
}

public struct WhatsNewStorePlan: Equatable, Sendable {
    public let action: WhatsNewStoreAction
    public let nextState: WhatsNewStoreState

    public init(action: WhatsNewStoreAction, nextState: WhatsNewStoreState) {
        self.action = action
        self.nextState = nextState
    }
}

public struct WhatsNewStore: Sendable {
    public init() {}

    public func plan(
        _ command: WhatsNewStoreCommand,
        from state: WhatsNewStoreState
    ) -> WhatsNewStorePlan {
        switch command {
        case let .recordLaunch(currentVersion, rawHTML):
            guard state.lastLaunchedVersion != currentVersion else {
                return WhatsNewStorePlan(action: .noChange, nextState: state)
            }

            return WhatsNewStorePlan(
                action: .showWhatsNew,
                nextState: WhatsNewStoreState(
                    pendingHTML: rawHTML.map(sanitizeHTML),
                    pendingVersion: currentVersion,
                    pendingPreviousVersion: state.lastLaunchedVersion,
                    lastLaunchedVersion: currentVersion
                )
            )

        case .dismissPending:
            return WhatsNewStorePlan(
                action: .dismissWhatsNew,
                nextState: WhatsNewStoreState(lastLaunchedVersion: state.lastLaunchedVersion)
            )
        }
    }

    private func sanitizeHTML(_ html: String) -> String {
        let withoutScripts = replacing(
            pattern: #"(?is)<script\b[^>]*>.*?</script>"#,
            in: html
        )
        return replacing(
            pattern: #"\s+on[a-zA-Z]+\s*=\s*"[^"]*""#,
            in: withoutScripts
        )
    }

    private func replacing(pattern: String, in value: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: "")
    }
}
