import Foundation

public struct SoundManagerSnapshot: Codable, Equatable, Sendable {
    public let settings: SoundManagerSettings
    public let filter: SoundFilter
    public let sourceSelections: [NotificationSoundCategory: SoundSourceSelection]
    public let soundPackStore: SoundPackStoreSnapshot
    public let customSoundStore: CustomSoundStoreSnapshot
    public let outputDevice: SoundOutputDeviceSnapshot?

    public init(
        settings: SoundManagerSettings = SoundManagerSettings(),
        filter: SoundFilter = SoundFilter(),
        sourceSelections: [NotificationSoundCategory: SoundSourceSelection] = [:],
        soundPackStore: SoundPackStoreSnapshot = SoundPackStoreSnapshot(),
        customSoundStore: CustomSoundStoreSnapshot = CustomSoundStoreSnapshot(),
        outputDevice: SoundOutputDeviceSnapshot? = SoundOutputDeviceSnapshot(
            id: "default",
            name: "Default Output",
            outputVolume: 1,
            observedAt: ""
        )
    ) {
        self.settings = settings
        self.filter = filter
        self.sourceSelections = sourceSelections
        self.soundPackStore = soundPackStore
        self.customSoundStore = customSoundStore
        self.outputDevice = outputDevice
    }
}

public struct SoundManagerPlaybackRequest: Codable, Equatable, Sendable {
    public let category: NotificationSoundCategory
    public let source: String?
    public let lifecycleEvent: SoundFilterPendingLifecycleEvent?
    public let subagentState: SoundFilterPendingSubagentState?
    public let minuteOfDay: Int

    public init(
        category: NotificationSoundCategory,
        source: String? = nil,
        lifecycleEvent: SoundFilterPendingLifecycleEvent? = nil,
        subagentState: SoundFilterPendingSubagentState? = nil,
        minuteOfDay: Int
    ) {
        self.category = category
        self.source = source
        self.lifecycleEvent = lifecycleEvent
        self.subagentState = subagentState
        self.minuteOfDay = min(max(minuteOfDay, 0), 1_439)
    }
}

public enum SoundManagerPlaybackAction: String, Codable, Equatable, Sendable {
    case playBuiltin8bit
    case playAppleSystem
    case playCustomSound
    case suppressSound
    case fallbackToSystemSound
}

public enum SoundManagerSuppressedReason: String, Codable, Equatable, Sendable {
    case managerDisabled
    case quietHours
    case filterRule
    case outputUnavailable
    case sourceOff
    case missingCustomSound
}

public struct SoundManagerPlaybackPlan: Codable, Equatable, Sendable {
    public let action: SoundManagerPlaybackAction
    public let category: NotificationSoundCategory
    public let sourceKind: SoundSourceKind?
    public let soundId: String?
    public let effectiveVolume: Double
    public let cooldownSeconds: Int
    public let suppressedReason: SoundManagerSuppressedReason?
    public let matchedFilterRuleId: String?

    public init(
        action: SoundManagerPlaybackAction,
        category: NotificationSoundCategory,
        sourceKind: SoundSourceKind? = nil,
        soundId: String? = nil,
        effectiveVolume: Double = 0,
        cooldownSeconds: Int = 0,
        suppressedReason: SoundManagerSuppressedReason? = nil,
        matchedFilterRuleId: String? = nil
    ) {
        self.action = action
        self.category = category
        self.sourceKind = sourceKind
        self.soundId = soundId
        self.effectiveVolume = min(max(effectiveVolume, 0), 1)
        self.cooldownSeconds = max(cooldownSeconds, 0)
        self.suppressedReason = suppressedReason
        self.matchedFilterRuleId = matchedFilterRuleId
    }
}

public struct SoundManager: Sendable {
    public let snapshot: SoundManagerSnapshot

    public init(snapshot: SoundManagerSnapshot = SoundManagerSnapshot()) {
        self.snapshot = snapshot
    }

    public func planPlayback(_ request: SoundManagerPlaybackRequest) -> SoundManagerPlaybackPlan {
        if !snapshot.settings.isEnabled {
            return suppressedPlan(for: request, reason: .managerDisabled)
        }

        if snapshot.settings.isQuiet(atMinuteOfDay: request.minuteOfDay) {
            return suppressedPlan(for: request, reason: .quietHours)
        }

        let filterDecision = snapshot.filter.decision(for: SoundFilterInput(
            category: request.category,
            source: request.source,
            lifecycleEvent: request.lifecycleEvent,
            subagentState: request.subagentState
        ))
        if !filterDecision.isAllowed {
            return SoundManagerPlaybackPlan(
                action: .suppressSound,
                category: request.category,
                suppressedReason: .filterRule,
                matchedFilterRuleId: filterDecision.matchedRuleId
            )
        }

        guard snapshot.outputDevice != nil else {
            return suppressedPlan(for: request, reason: .outputUnavailable)
        }

        let selection = SoundSourceStore(selections: snapshot.sourceSelections).resolve(category: request.category)
        guard selection.isEnabled, selection.sourceKind != .off else {
            return SoundManagerPlaybackPlan(
                action: .suppressSound,
                category: request.category,
                sourceKind: selection.sourceKind,
                suppressedReason: .sourceOff
            )
        }

        switch selection.sourceKind {
        case .builtin8bit:
            return playablePlan(action: .playBuiltin8bit, request: request, selection: selection)
        case .appleSystem:
            return playablePlan(action: .playAppleSystem, request: request, selection: selection)
        case .custom:
            return customSoundPlan(request: request, selection: selection)
        case .off:
            return SoundManagerPlaybackPlan(
                action: .suppressSound,
                category: request.category,
                sourceKind: selection.sourceKind,
                suppressedReason: .sourceOff
            )
        }
    }

    private func customSoundPlan(
        request: SoundManagerPlaybackRequest,
        selection: SoundSourceSelection
    ) -> SoundManagerPlaybackPlan {
        let customStore = CustomSoundStore(snapshot: snapshot.customSoundStore)
        let customFile: CustomSoundFile?
        if let soundId = selection.soundId {
            customFile = customStore.file(id: soundId)
        } else {
            customFile = customStore.assignedFile(for: request.category)
        }

        guard let customFile else {
            return SoundManagerPlaybackPlan(
                action: .fallbackToSystemSound,
                category: request.category,
                sourceKind: selection.sourceKind,
                soundId: selection.soundId,
                effectiveVolume: snapshot.settings.volume,
                cooldownSeconds: selection.cooldownSeconds,
                suppressedReason: .missingCustomSound
            )
        }

        return SoundManagerPlaybackPlan(
            action: .playCustomSound,
            category: request.category,
            sourceKind: selection.sourceKind,
            soundId: customFile.id,
            effectiveVolume: snapshot.settings.volume * selection.volume * customFile.playbackSettings.volume,
            cooldownSeconds: max(selection.cooldownSeconds, customFile.playbackSettings.cooldownSeconds)
        )
    }

    private func playablePlan(
        action: SoundManagerPlaybackAction,
        request: SoundManagerPlaybackRequest,
        selection: SoundSourceSelection
    ) -> SoundManagerPlaybackPlan {
        SoundManagerPlaybackPlan(
            action: action,
            category: request.category,
            sourceKind: selection.sourceKind,
            soundId: selection.soundId,
            effectiveVolume: snapshot.settings.volume * selection.volume,
            cooldownSeconds: selection.cooldownSeconds
        )
    }

    private func suppressedPlan(
        for request: SoundManagerPlaybackRequest,
        reason: SoundManagerSuppressedReason
    ) -> SoundManagerPlaybackPlan {
        SoundManagerPlaybackPlan(
            action: .suppressSound,
            category: request.category,
            suppressedReason: reason
        )
    }
}
