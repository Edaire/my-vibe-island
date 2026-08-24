import Foundation

/// V3 `QuietSceneMonitor` constructs its detector collection in this order.
/// Completion handling uses the first enabled detector reporting active.
public enum QuietSceneDetectorID: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case focus
    case screenObscured
    case screenCapture

    public var preferenceKey: String {
        "quietDetectorEnabled_\(rawValue)"
    }
}

public struct QuietSceneMonitorState: Codable, Equatable, Sendable {
    public let detectorEnabled: [QuietSceneDetectorID: Bool]
    public let detectorActive: [QuietSceneDetectorID: Bool]

    public init(
        detectorEnabled: [QuietSceneDetectorID: Bool] = [:],
        detectorActive: [QuietSceneDetectorID: Bool] = [:]
    ) {
        self.detectorEnabled = detectorEnabled
        self.detectorActive = detectorActive
    }

    public var activeDetector: QuietSceneDetectorID? {
        QuietSceneDetectorID.allCases.first { detector in
            detectorEnabled[detector] == true && detectorActive[detector] == true
        }
    }

    public var isQuietSceneActive: Bool {
        activeDetector != nil
    }
}

/// The parsed payload from V3's `duetexpertd` `log stream` source. V3 only
/// accepts lines carrying `semanticModeIdentifier:` and reads its
/// comma-delimited fields independently.
public struct FocusModeLogEvent: Equatable, Sendable {
    public let modeIdentifier: String
    public let isStarting: Bool
    public let semanticType: String?

    public init(modeIdentifier: String, isStarting: Bool, semanticType: String?) {
        self.modeIdentifier = modeIdentifier
        self.isStarting = isStarting
        self.semanticType = semanticType
    }

    public static func parse(_ line: String) -> FocusModeLogEvent? {
        guard line.contains("semanticModeIdentifier:") else { return nil }
        guard let modeIdentifier = value(for: "semanticModeIdentifier", in: line), !modeIdentifier.isEmpty else {
            return nil
        }
        return FocusModeLogEvent(
            modeIdentifier: modeIdentifier,
            isStarting: value(for: "starting", in: line) == "1",
            semanticType: value(for: "semanticType", in: line)
        )
    }

    private static func value(for key: String, in line: String) -> String? {
        guard let keyRange = line.range(of: "\(key):") else { return nil }
        let suffix = line[keyRange.upperBound...]
        let value = suffix.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

/// V3 only clears the active Focus value for a matching non-start event.
/// Keeping this state transition pure makes the log-source boundary testable.
public struct FocusModeActivityState: Equatable, Sendable {
    public private(set) var activeModeIdentifier: String?

    public init(activeModeIdentifier: String? = nil) {
        self.activeModeIdentifier = activeModeIdentifier
    }

    @discardableResult
    public mutating func apply(_ event: FocusModeLogEvent) -> Bool {
        let previous = activeModeIdentifier
        if event.isStarting {
            activeModeIdentifier = event.modeIdentifier
        } else if activeModeIdentifier == event.modeIdentifier {
            activeModeIdentifier = nil
        }
        return previous != activeModeIdentifier
    }
}
