import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitCarbonHotKeyController {
    public private(set) var refs: [HotKeyRef]
    public private(set) var lastRegistrationPlan: CarbonHotKeyRegistrationPlan?
    public private(set) var lastUnregistrationPlan: CarbonHotKeyUnregistrationPlan?

    private let controller: CarbonHotKeyController
    private let registerHotKey: @MainActor (HotKeyRef) -> Bool
    private let unregisterHotKey: @MainActor (HotKeyRef) -> Void
    private let runtime: MyVibeIslandAppKitCarbonHotKeyRuntime?

    public init(
        initialRefs: [HotKeyRef] = [],
        controller: CarbonHotKeyController = CarbonHotKeyController(),
        registerHotKey: @escaping @MainActor (HotKeyRef) -> Bool = { _ in true },
        unregisterHotKey: @escaping @MainActor (HotKeyRef) -> Void = { _ in }
    ) {
        self.refs = initialRefs
        self.controller = controller
        self.registerHotKey = registerHotKey
        self.unregisterHotKey = unregisterHotKey
        runtime = nil
    }

    init(
        runtime: MyVibeIslandAppKitCarbonHotKeyRuntime,
        controller: CarbonHotKeyController = CarbonHotKeyController()
    ) {
        refs = []
        self.controller = controller
        registerHotKey = { runtime.register($0) }
        unregisterHotKey = { runtime.unregister($0) }
        self.runtime = runtime
    }

    @discardableResult
    public func register(_ specs: [HotKeyRegistrationSpec]) -> CarbonHotKeyRegistrationPlan {
        let desiredIDs = Set(specs.map(\.id))
        for ref in refs where !desiredIDs.contains(ref.id) {
            unregisterHotKey(ref)
        }
        let retainedRefs = refs.filter { desiredIDs.contains($0.id) }
        let existingIds = Set(retainedRefs.map(\.id))
        let candidatePlan = controller.planRegistration(specs, existingRefs: retainedRefs)
        var registeredRefs: [HotKeyRef] = []
        var failures = candidatePlan.failures

        for ref in candidatePlan.registeredHotKeys {
            if existingIds.contains(ref.id) || registerHotKey(ref) {
                registeredRefs.append(ref)
            } else {
                failures.append(CarbonHotKeyRegistrationFailure(
                    specId: ref.id,
                    reason: .registrationRejected
                ))
            }
        }

        refs = registeredRefs
        let plan = CarbonHotKeyRegistrationPlan(
            registeredHotKeys: registeredRefs,
            failures: failures
        )
        lastRegistrationPlan = plan
        SessionCompletionTraceLog.append(
            stage: "shortcut.carbon.registration",
            sessionId: nil,
            metadata: [
                "registeredIDs": registeredRefs.map(\.id).joined(separator: ","),
                "failureIDs": failures.map(\.specId).joined(separator: ","),
            ]
        )
        return plan
    }

    @discardableResult
    public func unregister(ids: Set<String>) -> CarbonHotKeyUnregistrationPlan {
        let plan = controller.planUnregistration(ids: ids, from: refs)
        for ref in refs where plan.removedHotKeyIds.contains(ref.id) {
            unregisterHotKey(ref)
        }
        refs = plan.remainingHotKeys
        lastUnregistrationPlan = plan
        return plan
    }

    public func stop() {
        _ = unregister(ids: Set(refs.map(\.id)))
        runtime?.stop()
    }
}
