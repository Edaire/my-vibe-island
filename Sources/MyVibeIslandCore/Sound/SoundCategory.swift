import Foundation

public enum SoundCategory: String, Codable, Equatable, CaseIterable, Sendable {
    case sessionStart = "session.start"
    case taskAcknowledge = "task.acknowledge"
    case taskComplete = "task.complete"
    case taskError = "task.error"
    case inputRequired = "input.required"
    case resourceLimit = "resource.limit"
    case userSpam = "user.spam"
    case idleReminder = "vibe.idle.reminder"
    case usageWarning = "vibe.usage.warning"
    case usageReset = "vibe.usage.reset"

    public init(notificationCategory: NotificationSoundCategory) {
        switch notificationCategory {
        case .permission, .question:
            self = .inputRequired
        case .completion:
            self = .taskComplete
        case .failure:
            self = .taskError
        case .warning:
            self = .resourceLimit
        case .usage:
            self = .usageWarning
        case .remote:
            self = .sessionStart
        }
    }
}
