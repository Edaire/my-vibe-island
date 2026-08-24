import Carbon
import MyVibeIslandCore

public struct MyVibeIslandAppKitCarbonHotKeyRegistrationRequest: Equatable, Sendable {
    public let id: String
    public let carbonID: UInt32
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let signature: UInt32

    public init(id: String, carbonID: UInt32, keyCode: UInt32, modifiers: UInt32, signature: UInt32) {
        self.id = id
        self.carbonID = carbonID
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.signature = signature
    }
}

@MainActor
public final class MyVibeIslandAppKitCarbonHotKeyRuntime {
    public typealias InstallHandler = (@escaping @MainActor (UInt32) -> Void) -> Any?
    public typealias RegisterHotKey = (MyVibeIslandAppKitCarbonHotKeyRegistrationRequest) -> Any?

    private static let signature: UInt32 = 0x4D56_4942 // MVIB

    private let onHotKey: @MainActor (String) -> Void
    private let installHandler: InstallHandler
    private let removeHandler: (Any) -> Void
    private let registerHotKey: RegisterHotKey
    private let unregisterHotKey: (String, Any) -> Void
    private var handlerToken: Any?
    private var tokensByID: [String: Any] = [:]
    private var idsByCarbonID: [UInt32: String] = [:]
    private var registrationOrder: [String] = []

    public var isHandlerInstalled: Bool { handlerToken != nil }
    public var registeredHotKeyIDs: [String] { registrationOrder }

    public static var productionInstallHandler: InstallHandler { MyVibeIslandAppKitCarbonSystem.installHandler }
    public static var productionRemoveHandler: (Any) -> Void { MyVibeIslandAppKitCarbonSystem.removeHandler }
    public static var productionRegisterHotKey: RegisterHotKey { MyVibeIslandAppKitCarbonSystem.registerHotKey }
    public static var productionUnregisterHotKey: (String, Any) -> Void { MyVibeIslandAppKitCarbonSystem.unregisterHotKey }

    public init(
        onHotKey: @escaping @MainActor (String) -> Void,
        installHandler: @escaping InstallHandler = MyVibeIslandAppKitCarbonHotKeyRuntime.productionInstallHandler,
        removeHandler: @escaping (Any) -> Void = MyVibeIslandAppKitCarbonHotKeyRuntime.productionRemoveHandler,
        registerHotKey: @escaping RegisterHotKey = MyVibeIslandAppKitCarbonHotKeyRuntime.productionRegisterHotKey,
        unregisterHotKey: @escaping (String, Any) -> Void = MyVibeIslandAppKitCarbonHotKeyRuntime.productionUnregisterHotKey
    ) {
        self.onHotKey = onHotKey
        self.installHandler = installHandler
        self.removeHandler = removeHandler
        self.registerHotKey = registerHotKey
        self.unregisterHotKey = unregisterHotKey
    }

    public func register(_ ref: HotKeyRef) -> Bool {
        if tokensByID[ref.id] != nil {
            return true
        }
        guard ensureHandlerInstalled(),
              let carbonID = UInt32(exactly: ref.carbonId),
              let keyCode = UInt32(exactly: ref.keyCombo.keyCode),
              let modifiers = UInt32(exactly: ref.keyCombo.carbonModifiers)
        else {
            return false
        }
        let request = MyVibeIslandAppKitCarbonHotKeyRegistrationRequest(
            id: ref.id,
            carbonID: carbonID,
            keyCode: keyCode,
            modifiers: modifiers,
            signature: Self.signature
        )
        guard let token = registerHotKey(request) else {
            return false
        }
        tokensByID[ref.id] = token
        idsByCarbonID[carbonID] = ref.id
        registrationOrder.append(ref.id)
        return true
    }

    public func unregister(_ ref: HotKeyRef) {
        guard let token = tokensByID.removeValue(forKey: ref.id) else { return }
        unregisterHotKey(ref.id, token)
        idsByCarbonID = idsByCarbonID.filter { $0.value != ref.id }
        registrationOrder.removeAll { $0 == ref.id }
    }

    public func stop() {
        for id in registrationOrder {
            guard let token = tokensByID[id] else { continue }
            unregisterHotKey(id, token)
        }
        tokensByID.removeAll()
        idsByCarbonID.removeAll()
        registrationOrder.removeAll()
        if let handlerToken {
            removeHandler(handlerToken)
            self.handlerToken = nil
        }
    }

    private func ensureHandlerInstalled() -> Bool {
        if handlerToken != nil {
            return true
        }
        handlerToken = installHandler { [weak self] carbonID in
            guard let self, let id = self.idsByCarbonID[carbonID] else { return }
            self.onHotKey(id)
        }
        return handlerToken != nil
    }
}

private enum MyVibeIslandAppKitCarbonSystem {
    static func installHandler(_ callback: @escaping @MainActor (UInt32) -> Void) -> Any? {
        let box = CarbonCallbackBox(callback)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(box).toOpaque(),
            &handler
        )
        guard status == noErr, let handler else { return nil }
        return CarbonHandlerToken(handler: handler, box: box)
    }

    static func removeHandler(_ token: Any) {
        guard let token = token as? CarbonHandlerToken else { return }
        RemoveEventHandler(token.handler)
    }

    static func registerHotKey(_ request: MyVibeIslandAppKitCarbonHotKeyRegistrationRequest) -> Any? {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            request.keyCode,
            request.modifiers,
            EventHotKeyID(signature: request.signature, id: request.carbonID),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return nil }
        return CarbonHotKeyToken(ref: ref)
    }

    static func unregisterHotKey(_ id: String, _ token: Any) {
        guard let token = token as? CarbonHotKeyToken else { return }
        UnregisterEventHotKey(token.ref)
    }
}

private final class CarbonCallbackBox: @unchecked Sendable {
    let callback: @MainActor (UInt32) -> Void

    init(_ callback: @escaping @MainActor (UInt32) -> Void) {
        self.callback = callback
    }
}

private final class CarbonHandlerToken {
    let handler: EventHandlerRef
    let box: CarbonCallbackBox

    init(handler: EventHandlerRef, box: CarbonCallbackBox) {
        self.handler = handler
        self.box = box
    }
}

private final class CarbonHotKeyToken {
    let ref: EventHotKeyRef

    init(ref: EventHotKeyRef) {
        self.ref = ref
    }
}

private let carbonEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    var actualSize = 0
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        &actualSize,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let box = Unmanaged<CarbonCallbackBox>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        box.callback(hotKeyID.id)
    }
    return noErr
}
