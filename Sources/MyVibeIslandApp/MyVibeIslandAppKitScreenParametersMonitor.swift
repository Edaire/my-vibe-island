import AppKit

@MainActor
final class MyVibeIslandAppKitScreenParametersMonitor {
    static let originalScreenChangeDelayNanoseconds: UInt64 = 300_000_000

    private let notificationCenter: NotificationCenter
    private let onChange: @MainActor () -> Void
    private let screenChangeDelayNanoseconds: UInt64
    nonisolated(unsafe) private var observer: NSObjectProtocol?
    private var screenChangeTask: Task<Void, Never>?

    init(
        notificationCenter: NotificationCenter = .default,
        screenChangeDelayNanoseconds: UInt64 = originalScreenChangeDelayNanoseconds,
        onChange: @escaping @MainActor () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.screenChangeDelayNanoseconds = screenChangeDelayNanoseconds
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
                self?.scheduleScreenChangeRefresh()
            }
        }
    }

    func stop() {
        screenChangeTask?.cancel()
        screenChangeTask = nil
        guard let observer else { return }
        notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    deinit {
        screenChangeTask?.cancel()
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }

    private func scheduleScreenChangeRefresh() {
        screenChangeTask?.cancel()
        screenChangeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: screenChangeDelayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            screenChangeTask = nil
            onChange()
        }
    }
}
