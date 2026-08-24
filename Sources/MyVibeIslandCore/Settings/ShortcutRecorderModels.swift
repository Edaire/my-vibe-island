import Foundation

public struct ShortcutRecorderConflict: Codable, Equatable, Sendable {
    public let targetSpecId: String
    public let conflictingSpecId: String
    public let keyCombo: KeyCombo

    public init(
        targetSpecId: String,
        conflictingSpecId: String,
        keyCombo: KeyCombo
    ) {
        self.targetSpecId = targetSpecId
        self.conflictingSpecId = conflictingSpecId
        self.keyCombo = keyCombo
    }
}

public struct ShortcutRecorderState: Codable, Equatable, Sendable {
    public let activeSpecId: String?
    public let pendingCombo: KeyCombo?
    public let conflict: ShortcutRecorderConflict?

    public var isRecording: Bool {
        activeSpecId != nil
    }

    public var displayText: String {
        pendingCombo?.displayText ?? ""
    }

    public init(
        activeSpecId: String? = nil,
        pendingCombo: KeyCombo? = nil,
        conflict: ShortcutRecorderConflict? = nil
    ) {
        self.activeSpecId = activeSpecId
        self.pendingCombo = pendingCombo
        self.conflict = conflict
    }
}

public enum ShortcutRecorderDecision: String, Codable, Equatable, Sendable {
    case started
    case alreadyRecording
    case captured
    case conflict
    case cancelled
    case ignored
}

public struct ShortcutRecorderResult: Equatable, Sendable {
    public let decision: ShortcutRecorderDecision
    public let nextState: ShortcutRecorderState
    public let updatedSpec: HotKeyRegistrationSpec?

    public init(
        decision: ShortcutRecorderDecision,
        nextState: ShortcutRecorderState,
        updatedSpec: HotKeyRegistrationSpec? = nil
    ) {
        self.decision = decision
        self.nextState = nextState
        self.updatedSpec = updatedSpec
    }
}

public struct ShortcutRecorderModel: Sendable {
    public init() {}

    public func beginRecording(
        specId: String,
        from state: ShortcutRecorderState
    ) -> ShortcutRecorderResult {
        guard state.activeSpecId == nil || state.activeSpecId == specId else {
            return ShortcutRecorderResult(decision: .alreadyRecording, nextState: state)
        }

        return ShortcutRecorderResult(
            decision: .started,
            nextState: ShortcutRecorderState(activeSpecId: specId)
        )
    }

    public func capture(
        _ keyCombo: KeyCombo,
        for targetSpec: HotKeyRegistrationSpec,
        existingSpecs: [HotKeyRegistrationSpec],
        from state: ShortcutRecorderState
    ) -> ShortcutRecorderResult {
        guard state.activeSpecId == targetSpec.id else {
            return ShortcutRecorderResult(decision: .ignored, nextState: state)
        }

        if isEscape(keyCombo) {
            return ShortcutRecorderResult(decision: .cancelled, nextState: ShortcutRecorderState())
        }

        if let conflictingSpec = existingSpecs.first(where: { spec in
            spec.id != targetSpec.id
                && spec.isEnabled
                && spec.conflictPolicy == .reportConflict
                && spec.keyCombo == keyCombo
        }) {
            let conflict = ShortcutRecorderConflict(
                targetSpecId: targetSpec.id,
                conflictingSpecId: conflictingSpec.id,
                keyCombo: keyCombo
            )
            return ShortcutRecorderResult(
                decision: .conflict,
                nextState: ShortcutRecorderState(
                    activeSpecId: targetSpec.id,
                    pendingCombo: keyCombo,
                    conflict: conflict
                )
            )
        }

        let updatedSpec = HotKeyRegistrationSpec(
            id: targetSpec.id,
            action: targetSpec.action,
            keyCombo: keyCombo,
            scope: targetSpec.scope,
            isEnabled: targetSpec.isEnabled,
            conflictPolicy: targetSpec.conflictPolicy
        )

        return ShortcutRecorderResult(
            decision: .captured,
            nextState: ShortcutRecorderState(),
            updatedSpec: updatedSpec
        )
    }

    public func setEnabled(
        _ isEnabled: Bool,
        for spec: HotKeyRegistrationSpec
    ) -> HotKeyRegistrationSpec {
        HotKeyRegistrationSpec(
            id: spec.id,
            action: spec.action,
            keyCombo: spec.keyCombo,
            scope: spec.scope,
            isEnabled: isEnabled,
            conflictPolicy: spec.conflictPolicy
        )
    }

    private func isEscape(_ keyCombo: KeyCombo) -> Bool {
        keyCombo.keyCode == 53 || keyCombo.characters.lowercased() == "esc"
    }
}
