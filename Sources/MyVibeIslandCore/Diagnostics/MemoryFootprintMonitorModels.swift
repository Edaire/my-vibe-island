import Foundation

public enum MemoryPressureCategory: String, Codable, Equatable, Sendable {
    case unknown
    case normal
    case elevated
    case critical
}

public struct MemoryFootprintMonitorState: Codable, Equatable, Sendable {
    public let samples: [MemoryFootprintSnapshot]
    public let lastSampleError: String?

    public var latestSnapshot: MemoryFootprintSnapshot? {
        samples.last
    }

    public init(
        samples: [MemoryFootprintSnapshot] = [],
        lastSampleError: String? = nil
    ) {
        self.samples = samples
        self.lastSampleError = lastSampleError
    }
}

public struct MemoryFootprintMonitorSummary: Codable, Equatable, Sendable {
    public let latestSnapshot: MemoryFootprintSnapshot?
    public let sampleCount: Int
    public let lastSampleError: String?
    public let pressure: MemoryPressureCategory

    public init(
        latestSnapshot: MemoryFootprintSnapshot?,
        sampleCount: Int,
        lastSampleError: String?,
        pressure: MemoryPressureCategory
    ) {
        self.latestSnapshot = latestSnapshot
        self.sampleCount = sampleCount
        self.lastSampleError = lastSampleError
        self.pressure = pressure
    }
}

public struct MemoryFootprintMonitorModel: Sendable {
    public let warningThresholdBytes: Int64
    public let criticalThresholdBytes: Int64

    public init(
        warningThresholdBytes: Int64,
        criticalThresholdBytes: Int64
    ) {
        self.warningThresholdBytes = warningThresholdBytes
        self.criticalThresholdBytes = max(warningThresholdBytes, criticalThresholdBytes)
    }

    public func summary(for state: MemoryFootprintMonitorState) -> MemoryFootprintMonitorSummary {
        let pressure: MemoryPressureCategory
        if let latest = state.latestSnapshot {
            if latest.physicalFootprintBytes >= criticalThresholdBytes {
                pressure = .critical
            } else if latest.physicalFootprintBytes >= warningThresholdBytes {
                pressure = .elevated
            } else {
                pressure = .normal
            }
        } else {
            pressure = .unknown
        }

        return MemoryFootprintMonitorSummary(
            latestSnapshot: state.latestSnapshot,
            sampleCount: state.samples.count,
            lastSampleError: state.lastSampleError,
            pressure: pressure
        )
    }
}
