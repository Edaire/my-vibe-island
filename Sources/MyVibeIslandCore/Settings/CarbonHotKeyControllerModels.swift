import Foundation

public enum CarbonHotKeyRegistrationFailureReason: String, Codable, Equatable, Sendable {
    case registrationRejected
}

public struct CarbonHotKeyRegistrationFailure: Codable, Equatable, Sendable {
    public let specId: String
    public let reason: CarbonHotKeyRegistrationFailureReason

    public init(specId: String, reason: CarbonHotKeyRegistrationFailureReason) {
        self.specId = specId
        self.reason = reason
    }
}

public struct CarbonHotKeyRegistrationPlan: Codable, Equatable, Sendable {
    public let registeredHotKeys: [HotKeyRef]
    public let failures: [CarbonHotKeyRegistrationFailure]

    public init(
        registeredHotKeys: [HotKeyRef],
        failures: [CarbonHotKeyRegistrationFailure]
    ) {
        self.registeredHotKeys = registeredHotKeys
        self.failures = failures
    }
}

public struct CarbonHotKeyUnregistrationPlan: Codable, Equatable, Sendable {
    public let removedHotKeyIds: [String]
    public let remainingHotKeys: [HotKeyRef]

    public init(removedHotKeyIds: [String], remainingHotKeys: [HotKeyRef]) {
        self.removedHotKeyIds = removedHotKeyIds
        self.remainingHotKeys = remainingHotKeys
    }
}

public struct CarbonHotKeyController: Sendable {
    public init() {}

    public func planRegistration(
        _ specs: [HotKeyRegistrationSpec],
        existingRefs: [HotKeyRef] = [],
        rejectedSpecIds: Set<String> = []
    ) -> CarbonHotKeyRegistrationPlan {
        let existingById = Dictionary(uniqueKeysWithValues: existingRefs.map { ($0.id, $0) })
        var nextCarbonId = (existingRefs.map(\.carbonId).max() ?? 0) + 1
        var refs: [HotKeyRef] = []
        var failures: [CarbonHotKeyRegistrationFailure] = []

        for spec in specs {
            if let existing = existingById[spec.id] {
                refs.append(existing)
                continue
            }

            if rejectedSpecIds.contains(spec.id) {
                failures.append(CarbonHotKeyRegistrationFailure(
                    specId: spec.id,
                    reason: .registrationRejected
                ))
                continue
            }

            refs.append(HotKeyRef(
                id: spec.id,
                carbonId: nextCarbonId,
                keyCombo: spec.keyCombo,
                scope: spec.scope,
                action: spec.action
            ))
            nextCarbonId += 1
        }

        return CarbonHotKeyRegistrationPlan(
            registeredHotKeys: refs,
            failures: failures
        )
    }

    public func planUnregistration(
        ids: Set<String>,
        from refs: [HotKeyRef]
    ) -> CarbonHotKeyUnregistrationPlan {
        CarbonHotKeyUnregistrationPlan(
            removedHotKeyIds: refs.map(\.id).filter { ids.contains($0) },
            remainingHotKeys: refs.filter { !ids.contains($0.id) }
        )
    }
}
