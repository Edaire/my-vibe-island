import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitMemoryFootprintMonitorController {
    public private(set) var state: MemoryFootprintMonitorState
    public private(set) var lastSummary: MemoryFootprintMonitorSummary?

    private let monitor: MemoryFootprintMonitorModel
    private let publishSummary: @MainActor (MemoryFootprintMonitorSummary) -> Void

    public init(
        monitor: MemoryFootprintMonitorModel = MemoryFootprintMonitorModel(
            warningThresholdBytes: 512 * 1_024 * 1_024,
            criticalThresholdBytes: 1_024 * 1_024 * 1_024
        ),
        state: MemoryFootprintMonitorState = MemoryFootprintMonitorState(),
        publishSummary: @escaping @MainActor (MemoryFootprintMonitorSummary) -> Void = { _ in }
    ) {
        self.monitor = monitor
        self.state = state
        self.publishSummary = publishSummary
    }

    @discardableResult
    public func record(sample: MemoryFootprintSnapshot) -> MemoryFootprintMonitorSummary {
        state = MemoryFootprintMonitorState(
            samples: state.samples + [sample],
            lastSampleError: nil
        )
        return publishCurrentSummary()
    }

    @discardableResult
    public func recordSampleError(_ message: String) -> MemoryFootprintMonitorSummary {
        state = MemoryFootprintMonitorState(
            samples: state.samples,
            lastSampleError: message
        )
        return publishCurrentSummary()
    }

    private func publishCurrentSummary() -> MemoryFootprintMonitorSummary {
        let summary = monitor.summary(for: state)
        lastSummary = summary
        publishSummary(summary)
        return summary
    }
}
