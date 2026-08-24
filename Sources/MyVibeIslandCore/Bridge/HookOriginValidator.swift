public struct HookOriginValidatorSnapshot: Codable, Equatable, Sendable {
    public let probes: [HookOriginProbe]
    public let repairableProbeKeys: [String]

    public init(
        probes: [HookOriginProbe] = [],
        repairableProbeKeys: [String] = []
    ) {
        self.probes = probes
        self.repairableProbeKeys = repairableProbeKeys
    }
}

public struct HookOriginProbe: Codable, Equatable, Sendable {
    public let key: String
    public let hookBinaryPath: String?
    public let expectedBinaryPath: String?
    public let sourceConfigPath: String?
    public let currentHookCommandHash: String?
    public let eventName: String
    public let cwd: String?
    public let sourcePath: String?
    public let processBundleIdentifier: String?
    public let origin: HookCommandOrigin
    public let status: HookOriginValidationStatus

    public init(
        key: String,
        hookBinaryPath: String? = nil,
        expectedBinaryPath: String? = nil,
        sourceConfigPath: String? = nil,
        currentHookCommandHash: String? = nil,
        eventName: String,
        cwd: String? = nil,
        sourcePath: String? = nil,
        processBundleIdentifier: String? = nil,
        origin: HookCommandOrigin,
        status: HookOriginValidationStatus
    ) {
        self.key = key
        self.hookBinaryPath = hookBinaryPath
        self.expectedBinaryPath = expectedBinaryPath
        self.sourceConfigPath = sourceConfigPath
        self.currentHookCommandHash = currentHookCommandHash
        self.eventName = eventName
        self.cwd = cwd
        self.sourcePath = sourcePath
        self.processBundleIdentifier = processBundleIdentifier
        self.origin = origin
        self.status = status
    }
}

public enum HookCommandOrigin: String, Codable, Equatable, Sendable {
    case managed
    case userAuthored
    case unknown
    case disabled
}

public enum HookOriginValidationStatus: String, Codable, Equatable, Sendable {
    case trusted
    case unknown
    case mismatched
    case unmanaged
    case blocked
}
