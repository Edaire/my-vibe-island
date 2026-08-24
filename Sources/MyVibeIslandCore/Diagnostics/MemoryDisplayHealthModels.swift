import Foundation

public enum MemoryFootprintMonitor {
    public typealias Snapshot = MemoryFootprintSnapshot
}

public enum DisplaySleepObserver {
    public typealias Snapshot = DisplaySleepSnapshot

    public static let stateDidChangeEventName = "displaySleepStateDidChange"
}

public struct MemoryFootprintSnapshot: Codable, Equatable, Sendable {
    public let virtualBytes: Int64
    public let residentBytes: Int64
    public let physicalFootprintBytes: Int64
    public let compressedBytes: Int64
    public let reusableBytes: Int64

    public init(
        virtualBytes: Int64,
        residentBytes: Int64,
        physicalFootprintBytes: Int64,
        compressedBytes: Int64,
        reusableBytes: Int64
    ) {
        self.virtualBytes = virtualBytes
        self.residentBytes = residentBytes
        self.physicalFootprintBytes = physicalFootprintBytes
        self.compressedBytes = compressedBytes
        self.reusableBytes = reusableBytes
    }
}

public struct DisplaySleepSnapshot: Codable, Equatable, Sendable {
    public let isDisplayAsleep: Bool
    public let lastWakeAt: String?

    public init(
        isDisplayAsleep: Bool,
        lastWakeAt: String? = nil
    ) {
        self.isDisplayAsleep = isDisplayAsleep
        self.lastWakeAt = lastWakeAt
    }
}
