public struct SetupManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let helperBinaryPath: String
    public let managedBlockMarker: String
    public let sourceId: String
    public let eventNames: [String]
    public let installedCommand: String
    public let configPath: String
    public let managedPaths: [String]
    public let lastInstalledVersion: String?

    public init(
        schemaVersion: Int = 1,
        helperBinaryPath: String,
        managedBlockMarker: String,
        sourceId: String,
        eventNames: [String],
        installedCommand: String,
        configPath: String,
        managedPaths: [String] = [],
        lastInstalledVersion: String? = nil
    ) {
        self.schemaVersion = max(schemaVersion, 1)
        self.helperBinaryPath = helperBinaryPath
        self.managedBlockMarker = managedBlockMarker
        self.sourceId = sourceId
        self.eventNames = Array(Set(eventNames)).sorted()
        self.installedCommand = installedCommand
        self.configPath = configPath
        self.managedPaths = managedPaths
        self.lastInstalledVersion = lastInstalledVersion
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, helperBinaryPath, managedBlockMarker, sourceId, eventNames, installedCommand, configPath, managedPaths, lastInstalledVersion
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = max(try values.decode(Int.self, forKey: .schemaVersion), 1)
        helperBinaryPath = try values.decode(String.self, forKey: .helperBinaryPath)
        managedBlockMarker = try values.decode(String.self, forKey: .managedBlockMarker)
        sourceId = try values.decode(String.self, forKey: .sourceId)
        eventNames = try values.decode([String].self, forKey: .eventNames)
        installedCommand = try values.decode(String.self, forKey: .installedCommand)
        configPath = try values.decode(String.self, forKey: .configPath)
        managedPaths = try values.decodeIfPresent([String].self, forKey: .managedPaths) ?? []
        lastInstalledVersion = try values.decodeIfPresent(String.self, forKey: .lastInstalledVersion)
    }
}
