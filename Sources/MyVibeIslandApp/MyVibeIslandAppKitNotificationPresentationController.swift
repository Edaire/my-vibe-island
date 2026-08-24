import MyVibeIslandCore

public enum MyVibeIslandAppKitNotificationPresentationAction: Equatable {
    case presentPeek(NotchPeekNotification)
    case markUnread(PeekNotification)
    case requestSound(NotificationSoundRequest)
}

@MainActor
public final class MyVibeIslandAppKitNotificationPresentationController {
    public private(set) var lastAction: MyVibeIslandAppKitNotificationPresentationAction?

    private let presentPeekHandler: @MainActor (NotchPeekNotification) -> Void
    private let clearPeekHandler: @MainActor () -> Void
    private let shouldClearPeekHandler: @MainActor () -> Bool
    private let markUnreadHandler: @MainActor (PeekNotification) -> Void
    private let requestSoundHandler: @MainActor (NotificationSoundRequest) -> Void
    private var dismissTask: Task<Void, Never>?

    public init(
        presentPeek: @escaping @MainActor (NotchPeekNotification) -> Void = { _ in },
        clearPeek: @escaping @MainActor () -> Void = {},
        shouldClearPeek: @escaping @MainActor () -> Bool = { true },
        markUnread: @escaping @MainActor (PeekNotification) -> Void = { _ in },
        requestSound: @escaping @MainActor (NotificationSoundRequest) -> Void = { _ in }
    ) {
        self.presentPeekHandler = presentPeek
        self.clearPeekHandler = clearPeek
        self.shouldClearPeekHandler = shouldClearPeek
        self.markUnreadHandler = markUnread
        self.requestSoundHandler = requestSound
    }

    @discardableResult
    public func presentPeek(
        _ notification: PeekNotification,
        presentation: NotchPeekPresentation = .compact
    ) -> NotchPeekNotification {
        let notchNotification = NotchPeekNotification(
            notification: notification,
            presentation: presentation
        )
        lastAction = .presentPeek(notchNotification)
        if notification.category == .sessionCompleted {
            SessionCompletionTraceLog.append(
                stage: "notification.presentation",
                sessionId: notification.sessionId ?? notification.id,
                metadata: [
                    "category": notification.category.rawValue,
                    "rootResponseEffect": notification.rootResponseEffect?.rawValue ?? "nil",
                    "dwellSeconds": String(notification.dwellSeconds),
                    "presentation": String(describing: presentation),
                ]
            )
        }
        presentPeekHandler(notchNotification)
        dismissTask?.cancel()
        if notification.category == .sessionCompleted, notification.dwellSeconds >= 0 {
            if notification.dwellSeconds == 0 {
                if shouldClearPeekHandler() {
                    clearPeekHandler()
                }
                return notchNotification
            }
            let nanoseconds = UInt64(notification.dwellSeconds * 1_000_000_000)
            dismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                guard let self, self.shouldClearPeekHandler() else { return }
                self.clearPeekHandler()
            }
        }
        return notchNotification
    }

    public func markUnread(_ notification: PeekNotification) {
        lastAction = .markUnread(notification)
        markUnreadHandler(notification)
    }

    public func requestSound(_ request: NotificationSoundRequest) {
        lastAction = .requestSound(request)
        requestSoundHandler(request)
    }
}
