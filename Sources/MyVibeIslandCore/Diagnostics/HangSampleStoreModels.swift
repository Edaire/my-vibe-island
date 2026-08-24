import Foundation

public struct HangSampleStore: Codable, Equatable, Sendable {
    public private(set) var capacity: Int
    public private(set) var samples: [MainThreadHangSnapshot]

    public init(
        capacity: Int,
        samples: [MainThreadHangSnapshot] = []
    ) {
        self.capacity = max(1, capacity)
        self.samples = Array(samples.suffix(self.capacity))
    }

    public mutating func append(_ sample: MainThreadHangSnapshot) {
        samples.append(sample)
        if samples.count > capacity {
            samples = Array(samples.suffix(capacity))
        }
    }
}
