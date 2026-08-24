import AppKit
import Darwin
import MyVibeIslandCore

/// AppKit boundary for the V3 screen-obscured QuietScene detector. Focus and
/// capture remain separate because their original implementations use distinct
/// runtime sources (`FocusModeLogStream` and SkyLight respectively).
@MainActor
public final class MyVibeIslandAppKitQuietSceneMonitor {
    public private(set) var state: QuietSceneMonitorState

    private let defaults: UserDefaults
    private let publishStateDidChange: @MainActor (QuietSceneMonitorState) -> Void
    private let focusQuietModeIdentifiers: Set<String>
    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenCaptureTimer: Timer?
    private var focusActivity = FocusModeActivityState()
    private lazy var focusModeLogStream = MyVibeIslandAppKitFocusModeLogStream { [weak self] line in
        self?.observeFocusLogLine(line)
    }

    public init(
        defaults: UserDefaults = .standard,
        enabled: [QuietSceneDetectorID: Bool]? = nil,
        focusQuietModeIdentifiers: Set<String>? = nil,
        publishStateDidChange: @escaping @MainActor (QuietSceneMonitorState) -> Void = { _ in }
    ) {
        self.defaults = defaults
        self.publishStateDidChange = publishStateDidChange
        self.state = QuietSceneMonitorState(detectorEnabled: enabled ?? Self.enabledDetectors(defaults: defaults))
        self.focusQuietModeIdentifiers = focusQuietModeIdentifiers ?? Self.focusQuietModeIdentifiers(defaults: defaults)
    }

    isolated deinit {
        // The monitor owns a long-lived `log stream` process. Composition
        // instances are also created by integration tests, so teardown must
        // stop the process even when the app lifecycle is not driven through
        // the normal shutdown route.
        focusModeLogStream.stop()
        screenCaptureTimer?.invalidate()
        screenCaptureTimer = nil
        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.forEach(distributedCenter.removeObserver)
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
    }

    public var isQuietSceneActive: Bool {
        state.isQuietSceneActive
    }

    public func start() {
        guard distributedObservers.isEmpty, workspaceObservers.isEmpty else { return }
        let distributedCenter = DistributedNotificationCenter.default()
        for name in Self.screenObscuredNotificationNames {
            distributedObservers.append(distributedCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let isObscuring = Self.isObscuringNotification(notification.name)
                Task { @MainActor [weak self] in
                    self?.setScreenObscured(isObscuring)
                }
            })
        }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setScreenObscured(true) }
        })
        workspaceObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setScreenObscured(false) }
        })
        startScreenCapturePolling()
        if state.detectorEnabled[.focus] == true {
            focusModeLogStream.start()
        }
    }

    public func stop() {
        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.forEach(distributedCenter.removeObserver)
        distributedObservers.removeAll()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
        workspaceObservers.removeAll()
        screenCaptureTimer?.invalidate()
        screenCaptureTimer = nil
        focusModeLogStream.stop()
    }

    @discardableResult
    public func setScreenObscured(_ isObscured: Bool) -> Bool {
        setDetector(.screenObscured, active: isObscured)
    }

    /// Mirrors V3 `ScreenCaptureDetector`: update quiet state only when the
    /// dynamically-resolved SkyLight watcher state changes.
    @discardableResult
    public func setScreenCapture(_ isCapturing: Bool) -> Bool {
        setDetector(.screenCapture, active: isCapturing)
    }

    @discardableResult
    private func setDetector(_ detector: QuietSceneDetectorID, active isActive: Bool) -> Bool {
        var active = state.detectorActive
        guard active[detector] != isActive else { return false }
        active[detector] = isActive
        let next = QuietSceneMonitorState(
            detectorEnabled: state.detectorEnabled,
            detectorActive: active
        )
        guard next.isQuietSceneActive != state.isQuietSceneActive else {
            state = next
            return false
        }
        state = next
        publishStateDidChange(next)
        return true
    }

    public func observeDisplaySleep(_ snapshot: DisplaySleepSnapshot) {
        _ = setScreenObscured(snapshot.isDisplayAsleep)
    }

    func observeFocusLogLine(_ line: String) {
        guard let event = FocusModeLogEvent.parse(line) else { return }
        _ = focusActivity.apply(event)
        let activeMode = focusActivity.activeModeIdentifier
        _ = setDetector(
            .focus,
            active: activeMode.map(focusQuietModeIdentifiers.contains) ?? false
        )
    }

    private func startScreenCapturePolling() {
        guard screenCaptureTimer == nil else { return }
        // V3 uses `NSTimer.scheduledTimer(... repeats: true)` with 2.5s.
        screenCaptureTimer = Timer.scheduledTimer(
            withTimeInterval: 2.5,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.setScreenCapture(Self.isScreenWatcherPresent())
            }
        }
        _ = setScreenCapture(Self.isScreenWatcherPresent())
    }

    private static let screenObscuredNotificationNames: [Notification.Name] = [
        Notification.Name("com.apple.screensaver.didstart"),
        Notification.Name("com.apple.screensaver.didstop"),
        Notification.Name("com.apple.screenIsLocked"),
        Notification.Name("com.apple.screenIsUnlocked"),
    ]

    nonisolated private static func isObscuringNotification(_ name: Notification.Name) -> Bool {
        name.rawValue == "com.apple.screensaver.didstart" || name.rawValue == "com.apple.screenIsLocked"
    }

    nonisolated private static func isScreenWatcherPresent() -> Bool {
        screenWatcherQuery?() ?? false
    }

    /// V3 resolves the symbol once through `swift_once`, then calls the
    /// zero-argument function every poll. Retaining the handle also keeps the
    /// function address valid for the app lifetime.
    nonisolated private static let screenWatcherQuery: (@convention(c) () -> Bool)? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY
        ), let symbol = dlsym(handle, "CGSIsScreenWatcherPresent") else {
            return nil
        }
        _ = handle
        return unsafeBitCast(symbol, to: (@convention(c) () -> Bool).self)
    }()

    private static func enabledDetectors(defaults: UserDefaults) -> [QuietSceneDetectorID: Bool] {
        Dictionary(uniqueKeysWithValues: QuietSceneDetectorID.allCases.map { detector in
            let key = detector.preferenceKey
            let enabled: Bool
            if defaults.object(forKey: key) != nil {
                enabled = defaults.bool(forKey: key)
            } else if detector == .focus, defaults.object(forKey: "quietDuringFocusEnabled") != nil {
                enabled = defaults.bool(forKey: "quietDuringFocusEnabled")
            } else {
                enabled = false
            }
            return (detector, enabled)
        })
    }

    private static func focusQuietModeIdentifiers(defaults: UserDefaults) -> Set<String> {
        guard let data = defaults.data(forKey: "quietTriggerModeIds"),
              let identifiers = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(identifiers)
    }
}
