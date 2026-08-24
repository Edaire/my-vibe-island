import AppKit

@MainActor
final class MyVibeIslandAppKitScreenParametersMonitor {
    private let notificationCenter: NotificationCenter
    private let onChange: @MainActor () -> Void
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        onChange: @escaping @MainActor () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.onChange = onChange
    }

    func start() {
        guard observer == nil else { return }
        observer = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onChange()
            }
        }
    }

    func stop() {
        guard let observer else { return }
        notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }
}
