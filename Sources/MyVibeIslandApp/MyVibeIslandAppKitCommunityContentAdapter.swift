import MyVibeIslandCore

public struct MyVibeIslandAppKitCommunityRegistryRowDescriptor: Equatable {
    public let id: String
    public let displayName: String
    public let summary: String
    public let authorId: String
    public let authorDisplayName: String
    public let category: RegistryEntryCategory
    public let sourceURL: String?
    public let isExperimental: Bool
    public let isSelected: Bool

    public init(
        id: String,
        displayName: String,
        summary: String,
        authorId: String,
        authorDisplayName: String,
        category: RegistryEntryCategory,
        sourceURL: String?,
        isExperimental: Bool,
        isSelected: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.category = category
        self.sourceURL = sourceURL
        self.isExperimental = isExperimental
        self.isSelected = isSelected
    }
}

public struct MyVibeIslandAppKitCommunityContentDescriptor: Equatable {
    public let state: CommunitySheetState
    public let visibleSections: [CommunitySheetSection]
    public let requiresRegistryFetch: Bool
    public let documentationURL: String?
    public let supportURL: String?
    public let discordTitle: String?
    public let discordInviteURL: String?
    public let discordMemberCount: Int?
    public let isDiscordVisible: Bool
    public let registryEntryCount: Int
    public let experimentalRegistryEntryCount: Int
    public let selectedEntryId: String?
    public let registryRows: [MyVibeIslandAppKitCommunityRegistryRowDescriptor]

    public init(
        state: CommunitySheetState,
        visibleSections: [CommunitySheetSection],
        requiresRegistryFetch: Bool,
        documentationURL: String?,
        supportURL: String?,
        discordTitle: String?,
        discordInviteURL: String?,
        discordMemberCount: Int?,
        isDiscordVisible: Bool,
        registryEntryCount: Int,
        experimentalRegistryEntryCount: Int,
        selectedEntryId: String?,
        registryRows: [MyVibeIslandAppKitCommunityRegistryRowDescriptor]
    ) {
        self.state = state
        self.visibleSections = visibleSections
        self.requiresRegistryFetch = requiresRegistryFetch
        self.documentationURL = documentationURL
        self.supportURL = supportURL
        self.discordTitle = discordTitle
        self.discordInviteURL = discordInviteURL
        self.discordMemberCount = discordMemberCount
        self.isDiscordVisible = isDiscordVisible
        self.registryEntryCount = max(registryEntryCount, 0)
        self.experimentalRegistryEntryCount = max(experimentalRegistryEntryCount, 0)
        self.selectedEntryId = selectedEntryId
        self.registryRows = registryRows
    }
}

public struct MyVibeIslandAppKitCommunityContentAdapter {
    public init() {}

    public func makeDescriptor(
        config: CommunityConfig,
        skeleton: CommunitySheetSkeleton
    ) -> MyVibeIslandAppKitCommunityContentDescriptor {
        let registry = config.registry
        return MyVibeIslandAppKitCommunityContentDescriptor(
            state: skeleton.state,
            visibleSections: skeleton.visibleSections,
            requiresRegistryFetch: skeleton.requiresRegistryFetch,
            documentationURL: config.documentationURL,
            supportURL: config.supportURL,
            discordTitle: config.discord?.title,
            discordInviteURL: config.discord?.inviteURL,
            discordMemberCount: config.discord?.memberCount,
            isDiscordVisible: config.discord?.isVisible ?? false,
            registryEntryCount: registry?.entryCount ?? 0,
            experimentalRegistryEntryCount: registry?.experimentalEntryCount ?? 0,
            selectedEntryId: skeleton.selectedEntryId,
            registryRows: registryRows(from: registry, selectedEntryId: skeleton.selectedEntryId)
        )
    }

    private func registryRows(
        from registry: RegistryIndex?,
        selectedEntryId: String?
    ) -> [MyVibeIslandAppKitCommunityRegistryRowDescriptor] {
        registry?.entries.map { entry in
            MyVibeIslandAppKitCommunityRegistryRowDescriptor(
                id: entry.id,
                displayName: entry.displayName,
                summary: entry.summary,
                authorId: entry.author.id,
                authorDisplayName: entry.author.displayName,
                category: entry.category,
                sourceURL: entry.sourceURL,
                isExperimental: entry.isExperimental,
                isSelected: entry.id == selectedEntryId
            )
        } ?? []
    }
}
