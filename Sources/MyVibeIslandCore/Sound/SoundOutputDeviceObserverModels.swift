import Foundation

public struct SoundOutputDeviceSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let outputVolume: Double
    public let observedAt: String

    public init(
        id: String,
        name: String,
        outputVolume: Double,
        observedAt: String
    ) {
        self.id = id
        self.name = name
        self.outputVolume = min(max(outputVolume, 0), 1)
        self.observedAt = observedAt
    }
}

public enum SoundOutputDeviceChangeKind: String, Codable, Equatable, Sendable {
    case noDevice
    case deviceSelected
    case deviceChanged
    case labelChanged
    case volumeChanged
}

public struct SoundOutputDeviceChange: Codable, Equatable, Sendable {
    public let kind: SoundOutputDeviceChangeKind
    public let previous: SoundOutputDeviceSnapshot?
    public let current: SoundOutputDeviceSnapshot?

    public init(
        kind: SoundOutputDeviceChangeKind,
        previous: SoundOutputDeviceSnapshot? = nil,
        current: SoundOutputDeviceSnapshot? = nil
    ) {
        self.kind = kind
        self.previous = previous
        self.current = current
    }
}

public struct SoundOutputDeviceObserver: Sendable {
    public init() {}

    public func change(
        from previous: SoundOutputDeviceSnapshot?,
        to current: SoundOutputDeviceSnapshot?
    ) -> SoundOutputDeviceChange? {
        switch (previous, current) {
        case (nil, nil):
            return nil
        case (nil, .some):
            return SoundOutputDeviceChange(kind: .deviceSelected, previous: previous, current: current)
        case (.some, nil):
            return SoundOutputDeviceChange(kind: .noDevice, previous: previous, current: current)
        case let (.some(previous), .some(current)):
            if previous.id != current.id {
                return SoundOutputDeviceChange(kind: .deviceChanged, previous: previous, current: current)
            }
            if previous.name != current.name {
                return SoundOutputDeviceChange(kind: .labelChanged, previous: previous, current: current)
            }
            if previous.outputVolume != current.outputVolume {
                return SoundOutputDeviceChange(kind: .volumeChanged, previous: previous, current: current)
            }
            return nil
        }
    }
}
