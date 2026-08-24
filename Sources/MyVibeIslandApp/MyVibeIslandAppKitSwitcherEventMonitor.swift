@preconcurrency import AppKit
import MyVibeIslandCore

@MainActor
final class MyVibeIslandAppKitSwitcherEventMonitor {
    struct Input: Sendable {
        let typeRawValue: UInt
        let modifierFlagsRawValue: UInt
        let location: DisplayPoint

        init(_ event: NSEvent) {
            typeRawValue = event.type.rawValue
            modifierFlagsRawValue = event.modifierFlags.rawValue
            location = DisplayPoint(x: event.locationInWindow.x, y: event.locationInWindow.y)
        }

        init(type: NSEvent.EventType, modifierFlags: NSEvent.ModifierFlags, location: NSPoint) {
            typeRawValue = type.rawValue
            modifierFlagsRawValue = modifierFlags.rawValue
            self.location = DisplayPoint(x: location.x, y: location.y)
        }
    }

    typealias LocalRegistration = (
        NSEvent.EventTypeMask,
        @escaping @MainActor (Input) -> Void
    ) -> Any?
    typealias GlobalRegistration = (
        NSEvent.EventTypeMask,
        @escaping @MainActor (Input) -> Void
    ) -> Any?

    private static let eventMask: NSEvent.EventTypeMask = [
        .flagsChanged,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
    ]

    private let coordinator: MyVibeIslandAppKitSwitcherCoordinator
    private let modifierReleased: () -> Void
    private let modifierFlags: () -> NSEvent.ModifierFlags
    private let currentModifierFlags: () -> NSEvent.ModifierFlags
    private let interactionFrame: () -> DisplayFrame?
    private let registerLocal: LocalRegistration
    private let registerGlobal: GlobalRegistration
    private let removeMonitor: (Any) -> Void
    nonisolated(unsafe) private var localToken: Any?
    nonisolated(unsafe) private var globalToken: Any?
    private var configuredModifierWasHeld = false

    private(set) var isStarted = false

    deinit {
        if let localToken {
            NSEvent.removeMonitor(localToken)
        }
        if let globalToken {
            NSEvent.removeMonitor(globalToken)
        }
    }

    init(
        coordinator: MyVibeIslandAppKitSwitcherCoordinator,
        modifierReleased: (() -> Void)? = nil,
        modifierFlags: @escaping () -> NSEvent.ModifierFlags,
        currentModifierFlags: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags },
        interactionFrame: @escaping () -> DisplayFrame?,
        registerLocal: @escaping LocalRegistration = { mask, callback in
            NSEvent.addLocalMonitorForEvents(matching: mask) { event in
                let input = Input(
                    type: event.type,
                    modifierFlags: event.modifierFlags,
                    location: NSEvent.mouseLocation
                )
                MainActor.assumeIsolated { callback(input) }
                return event
            }
        },
        registerGlobal: @escaping GlobalRegistration = { mask, callback in
            NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
                let input = Input(
                    type: event.type,
                    modifierFlags: event.modifierFlags,
                    location: event.locationInWindow
                )
                Task { @MainActor in callback(input) }
            }
        },
        removeMonitor: @escaping (Any) -> Void = NSEvent.removeMonitor
    ) {
        self.coordinator = coordinator
        self.modifierReleased = modifierReleased ?? coordinator.modifierReleased
        self.modifierFlags = modifierFlags
        self.currentModifierFlags = currentModifierFlags
        self.interactionFrame = interactionFrame
        self.registerLocal = registerLocal
        self.registerGlobal = registerGlobal
        self.removeMonitor = removeMonitor
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        configuredModifierWasHeld = currentModifierFlags().contains(modifierFlags())
        localToken = registerLocal(Self.eventMask) { [weak self] input in
            self?.handle(input)
        }
        globalToken = registerGlobal(Self.eventMask) { [weak self] input in
            self?.handle(input)
        }
    }

    func stop() {
        guard isStarted else { return }
        if let localToken {
            removeMonitor(localToken)
        }
        if let globalToken {
            removeMonitor(globalToken)
        }
        localToken = nil
        globalToken = nil
        configuredModifierWasHeld = false
        isStarted = false
    }

    private func handle(_ input: Input) {
        guard coordinator.state.isOpen else {
            configuredModifierWasHeld = false
            return
        }

        switch NSEvent.EventType(rawValue: input.typeRawValue) {
        case .flagsChanged:
            let flags = NSEvent.ModifierFlags(rawValue: input.modifierFlagsRawValue)
            let isHeld = flags.contains(modifierFlags())
            if configuredModifierWasHeld, !isHeld {
                configuredModifierWasHeld = false
                modifierReleased()
                stop()
            } else {
                configuredModifierWasHeld = isHeld
            }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard let frame = interactionFrame(), !frame.contains(input.location) else {
                return
            }
            coordinator.outsideInteraction()
            stop()
        default:
            break
        }
    }

}

extension ModifierKeyOption {
    var eventModifierFlags: NSEvent.ModifierFlags {
        switch self {
        case .command: .command
        case .option: .option
        case .control: .control
        case .shift: .shift
        }
    }
}

private extension DisplayFrame {
    func contains(_ point: DisplayPoint) -> Bool {
        point.x >= x && point.x <= x + width && point.y >= y && point.y <= y + height
    }
}
