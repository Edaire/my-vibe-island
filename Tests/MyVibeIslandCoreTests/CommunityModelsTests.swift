import XCTest
@testable import MyVibeIslandCore

final class CommunityModelsTests: XCTestCase {
    func testCommunityModelsMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CommunityModelsMatrixFixture.self,
            from: try FixtureLoader.data("community/community-models-matrix")
        )

        let localConfig = CommunityConfig(
            documentationURL: "https://example.invalid/docs",
            supportURL: "https://example.invalid/support",
            discord: DiscordCard(
                title: "Community",
                inviteURL: "https://example.invalid/discord",
                memberCount: 42,
                isVisible: true
            ),
            registry: nil
        )
        let registry = registryIndex()

        let actual = CommunityModelsMatrixFixture(rows: [
            CommunityModelsMatrixRow(
                id: "local-links-no-registry",
                config: localConfig,
                skeleton: CommunitySheetSkeleton(
                    state: .localOnly,
                    visibleSections: [.discord, .documentation]
                )
            ),
            CommunityModelsMatrixRow(
                id: "registry-index-summary",
                config: CommunityConfig(
                    documentationURL: nil,
                    supportURL: nil,
                    discord: nil,
                    registry: registry
                ),
                skeleton: CommunitySheetSkeleton(
                    state: .registryAvailable,
                    visibleSections: [.registry],
                    selectedEntryId: "theme-8bit"
                )
            ),
            CommunityModelsMatrixRow(
                id: "loading-registry-deferred-boundary",
                config: CommunityConfig(),
                skeleton: CommunitySheetSkeleton(
                    state: .loadingRegistry,
                    visibleSections: [.registry]
                )
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testCommunityConfigRoundTripsDocsAndCommunityLinksWithoutRegistryBrowsing() throws {
        let config = CommunityConfig(
            documentationURL: "https://example.invalid/docs",
            supportURL: "https://example.invalid/support",
            discord: DiscordCard(
                title: "Community",
                inviteURL: "https://example.invalid/discord",
                memberCount: 42,
                isVisible: true
            ),
            registry: nil
        )

        let decoded = try JSONDecoder().decode(
            CommunityConfig.self,
            from: try JSONEncoder().encode(config)
        )

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.discord?.memberCount, 42)
        XCTAssertFalse(decoded.hasRegistryBrowsing)
    }

    func testRegistryIndexBuildsStableEntrySummaries() {
        let index = RegistryIndex(entries: [
            RegistryEntry(
                id: "theme-8bit",
                displayName: "8 Bit Theme",
                summary: "Local sound theme",
                author: RegistryAuthor(id: "author-1", displayName: "Contributor"),
                category: .soundPack,
                sourceURL: "https://example.invalid/theme",
                isExperimental: false
            ),
            RegistryEntry(
                id: "lab-kiro",
                displayName: "Kiro Lab",
                summary: "Experimental agent metadata",
                author: RegistryAuthor(id: "author-2", displayName: "Lab Contributor"),
                category: .labsTool,
                sourceURL: nil,
                isExperimental: true
            )
        ])

        XCTAssertEqual(index.entryCount, 2)
        XCTAssertEqual(index.experimentalEntryCount, 1)
        XCTAssertEqual(index.entries.map(\.category), [.soundPack, .labsTool])
    }

    func testCommunitySheetSkeletonIsDisplayOnlyState() {
        let skeleton = CommunitySheetSkeleton(
            state: .deferred,
            visibleSections: [.discord, .documentation],
            selectedEntryId: nil
        )

        XCTAssertEqual(skeleton.state, .deferred)
        XCTAssertEqual(skeleton.visibleSections, [.discord, .documentation])
        XCTAssertFalse(skeleton.requiresRegistryFetch)
    }

    private func registryIndex() -> RegistryIndex {
        RegistryIndex(entries: [
            RegistryEntry(
                id: "theme-8bit",
                displayName: "8 Bit Theme",
                summary: "Local sound theme",
                author: RegistryAuthor(id: "author-1", displayName: "Contributor"),
                category: .soundPack,
                sourceURL: "https://example.invalid/theme",
                isExperimental: false
            ),
            RegistryEntry(
                id: "lab-kiro",
                displayName: "Kiro Lab",
                summary: "Experimental agent metadata",
                author: RegistryAuthor(id: "author-2", displayName: "Lab Contributor"),
                category: .labsTool,
                sourceURL: nil,
                isExperimental: true
            )
        ])
    }
}

private struct CommunityModelsMatrixFixture: Codable, Equatable {
    let rows: [CommunityModelsMatrixRow]
}

private struct CommunityModelsMatrixRow: Codable, Equatable {
    let id: String
    let hasDocumentationURL: Bool
    let hasSupportURL: Bool
    let discordVisible: Bool
    let discordMemberCount: Int?
    let hasRegistryBrowsing: Bool
    let registryEntryCount: Int
    let experimentalEntryCount: Int
    let registryCategories: [RegistryEntryCategory]
    let skeletonState: CommunitySheetState
    let visibleSections: [CommunitySheetSection]
    let selectedEntryId: String?
    let requiresRegistryFetch: Bool

    init(id: String, config: CommunityConfig, skeleton: CommunitySheetSkeleton) {
        self.id = id
        hasDocumentationURL = config.documentationURL != nil
        hasSupportURL = config.supportURL != nil
        discordVisible = config.discord?.isVisible ?? false
        discordMemberCount = config.discord?.memberCount
        hasRegistryBrowsing = config.hasRegistryBrowsing
        registryEntryCount = config.registry?.entryCount ?? 0
        experimentalEntryCount = config.registry?.experimentalEntryCount ?? 0
        registryCategories = config.registry?.entries.map(\.category) ?? []
        skeletonState = skeleton.state
        visibleSections = skeleton.visibleSections
        selectedEntryId = skeleton.selectedEntryId
        requiresRegistryFetch = skeleton.requiresRegistryFetch
    }
}
