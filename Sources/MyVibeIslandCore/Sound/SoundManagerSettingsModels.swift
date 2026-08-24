import Foundation

public struct SoundManagerSettings: Codable, Equatable, Sendable {
    public let selectedPackId: String?
    public let isEnabled: Bool
    public let volume: Double
    public let quietHoursEnabled: Bool
    public let quietHoursStartMinutes: Int
    public let quietHoursEndMinutes: Int
    public let isCeremonyLoadInProgress: Bool
    public let shouldAutoplayCeremonyWhenReady: Bool
    public let ceremonyLoadGeneration: Int

    public init(
        selectedPackId: String? = nil,
        isEnabled: Bool = true,
        volume: Double = 1,
        quietHoursEnabled: Bool = false,
        quietHoursStartMinutes: Int = 22 * 60,
        quietHoursEndMinutes: Int = 7 * 60,
        isCeremonyLoadInProgress: Bool = false,
        shouldAutoplayCeremonyWhenReady: Bool = false,
        ceremonyLoadGeneration: Int = 0
    ) {
        self.selectedPackId = selectedPackId
        self.isEnabled = isEnabled
        self.volume = min(max(volume, 0), 1)
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStartMinutes = Self.clampedMinute(quietHoursStartMinutes)
        self.quietHoursEndMinutes = Self.clampedMinute(quietHoursEndMinutes)
        self.isCeremonyLoadInProgress = isCeremonyLoadInProgress
        self.shouldAutoplayCeremonyWhenReady = shouldAutoplayCeremonyWhenReady
        self.ceremonyLoadGeneration = max(ceremonyLoadGeneration, 0)
    }

    public func isQuiet(atMinuteOfDay minute: Int) -> Bool {
        guard quietHoursEnabled else {
            return false
        }

        let checkedMinute = Self.clampedMinute(minute)
        if quietHoursStartMinutes == quietHoursEndMinutes {
            return true
        }

        if quietHoursStartMinutes < quietHoursEndMinutes {
            return checkedMinute >= quietHoursStartMinutes && checkedMinute < quietHoursEndMinutes
        }

        return checkedMinute >= quietHoursStartMinutes || checkedMinute < quietHoursEndMinutes
    }

    private static func clampedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 1_439)
    }
}
