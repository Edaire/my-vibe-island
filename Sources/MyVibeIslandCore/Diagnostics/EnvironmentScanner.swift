public struct EnvironmentScannerPlan: Codable, Equatable, Sendable {
    public let scannedAt: String?
    public let knownConfigPaths: [String]
    public let knownCLICommandNames: [String]
    public let appBundlePresent: Bool
    public let hookBinaryPath: String?
    public let hookBinaryVersion: String?
    public let terminalObservations: [EnvironmentTerminalObservation]
    public let agentObservations: [EnvironmentAgentObservation]
    public let onboardingContext: String?
    public let exportSections: [String]

    public init(
        scannedAt: String? = nil,
        knownConfigPaths: [String] = [],
        knownCLICommandNames: [String] = [],
        appBundlePresent: Bool = false,
        hookBinaryPath: String? = nil,
        hookBinaryVersion: String? = nil,
        terminalObservations: [EnvironmentTerminalObservation] = [],
        agentObservations: [EnvironmentAgentObservation] = [],
        onboardingContext: String? = nil,
        exportSections: [String] = []
    ) {
        self.scannedAt = scannedAt
        self.knownConfigPaths = knownConfigPaths
        self.knownCLICommandNames = knownCLICommandNames
        self.appBundlePresent = appBundlePresent
        self.hookBinaryPath = hookBinaryPath
        self.hookBinaryVersion = hookBinaryVersion
        self.terminalObservations = terminalObservations
        self.agentObservations = agentObservations
        self.onboardingContext = onboardingContext
        self.exportSections = exportSections
    }

    public func scanResult() -> EnvironmentScanResult {
        EnvironmentScanResult(
            scannedAt: scannedAt,
            agents: agentObservations.map(\.agentInfo),
            terminals: terminalObservations.map(\.terminalInfo)
        )
    }
}

public struct EnvironmentAgentObservation: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isInstalled: Bool
    public let isConfigured: Bool
    public let cliVersionSummary: String?
    public let confidence: EnvironmentScannerEvidenceConfidence
    public let repairHint: String?

    public init(
        id: String,
        name: String,
        isInstalled: Bool,
        isConfigured: Bool,
        cliVersionSummary: String? = nil,
        confidence: EnvironmentScannerEvidenceConfidence,
        repairHint: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isInstalled = isInstalled
        self.isConfigured = isConfigured
        self.cliVersionSummary = cliVersionSummary
        self.confidence = confidence
        self.repairHint = repairHint
    }

    public var agentInfo: EnvironmentAgentInfo {
        EnvironmentAgentInfo(
            id: id,
            name: name,
            isDetected: isInstalled,
            isInstalled: isInstalled,
            isConfigured: isConfigured,
            repairability: repairHint == nil ? .notNeeded : .repairable
        )
    }
}

public struct EnvironmentTerminalObservation: Codable, Equatable, Sendable {
    public let name: String
    public let isRunning: Bool
    public let activeContextCount: Int

    public init(
        name: String,
        isRunning: Bool,
        activeContextCount: Int
    ) {
        self.name = name
        self.isRunning = isRunning
        self.activeContextCount = activeContextCount
    }

    public var terminalInfo: EnvironmentTerminalInfo {
        EnvironmentTerminalInfo(name: name, isDetected: isRunning)
    }
}

public enum EnvironmentScannerEvidenceConfidence: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}
