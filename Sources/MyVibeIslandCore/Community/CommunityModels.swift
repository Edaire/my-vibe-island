import Foundation

public struct CommunityConfig: Codable, Equatable, Sendable {
    public let documentationURL: String?
    public let supportURL: String?
    public let discord: DiscordCard?
    public let registry: RegistryIndex?

    public var hasRegistryBrowsing: Bool {
        registry != nil
    }

    public init(
        documentationURL: String? = nil,
        supportURL: String? = nil,
        discord: DiscordCard? = nil,
        registry: RegistryIndex? = nil
    ) {
        self.documentationURL = documentationURL
        self.supportURL = supportURL
        self.discord = discord
        self.registry = registry
    }
}

public struct DiscordCard: Codable, Equatable, Sendable {
    public let title: String
    public let inviteURL: String?
    public let memberCount: Int?
    public let isVisible: Bool

    public init(
        title: String,
        inviteURL: String? = nil,
        memberCount: Int? = nil,
        isVisible: Bool = false
    ) {
        self.title = title
        self.inviteURL = inviteURL
        self.memberCount = memberCount
        self.isVisible = isVisible
    }
}

public struct RegistryIndex: Codable, Equatable, Sendable {
    public let entries: [RegistryEntry]

    public var entryCount: Int {
        entries.count
    }

    public var experimentalEntryCount: Int {
        entries.filter(\.isExperimental).count
    }

    public init(entries: [RegistryEntry] = []) {
        self.entries = entries
    }
}

public struct RegistryEntry: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let summary: String
    public let author: RegistryAuthor
    public let category: RegistryEntryCategory
    public let sourceURL: String?
    public let isExperimental: Bool

    public init(
        id: String,
        displayName: String,
        summary: String,
        author: RegistryAuthor,
        category: RegistryEntryCategory,
        sourceURL: String? = nil,
        isExperimental: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.author = author
        self.category = category
        self.sourceURL = sourceURL
        self.isExperimental = isExperimental
    }
}

public struct RegistryAuthor: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public enum RegistryEntryCategory: String, Codable, Equatable, Sendable {
    case soundPack
    case labsTool
    case integration
    case documentation
}

public struct CommunitySheetSkeleton: Codable, Equatable, Sendable {
    public let state: CommunitySheetState
    public let visibleSections: [CommunitySheetSection]
    public let selectedEntryId: String?

    public var requiresRegistryFetch: Bool {
        state == .loadingRegistry
    }

    public init(
        state: CommunitySheetState = .deferred,
        visibleSections: [CommunitySheetSection] = [],
        selectedEntryId: String? = nil
    ) {
        self.state = state
        self.visibleSections = visibleSections
        self.selectedEntryId = selectedEntryId
    }
}

public enum CommunitySheetState: String, Codable, Equatable, Sendable {
    case deferred
    case localOnly
    case loadingRegistry
    case registryAvailable
}

public enum CommunitySheetSection: String, Codable, Equatable, Sendable {
    case discord
    case documentation
    case registry
}
