import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitCommunityContentAdapterTests: XCTestCase {
    func testCommunityContentAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CommunityContentAdapterMatrixFixture.self,
            from: try AppFixtureLoader.data("app/community-content-adapter-matrix")
        )

        let actual = CommunityContentAdapterMatrixFixture(rows: [
            row(
                id: "registry-available-with-selection",
                config: CommunityConfig(
                    documentationURL: "https://example.invalid/docs",
                    supportURL: "https://example.invalid/support",
                    discord: DiscordCard(
                        title: "Community",
                        inviteURL: "https://example.invalid/discord",
                        memberCount: 42,
                        isVisible: true
                    ),
                    registry: RegistryIndex(entries: [
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
                            isExperimental: true
                        )
                    ])
                ),
                skeleton: CommunitySheetSkeleton(
                    state: .registryAvailable,
                    visibleSections: [.discord, .documentation, .registry],
                    selectedEntryId: "lab-kiro"
                )
            ),
            row(
                id: "loading-registry-local-links-only",
                config: CommunityConfig(
                    documentationURL: "https://example.invalid/docs",
                    supportURL: "https://example.invalid/support"
                ),
                skeleton: CommunitySheetSkeleton(
                    state: .loadingRegistry,
                    visibleSections: [.documentation, .registry]
                )
            )
        ])

        XCTAssertEqual(actual, expected)
    }

    func testAdapterBuildsLocalCommunityDescriptorWithoutRuntimeFetch() {
        let adapter = MyVibeIslandAppKitCommunityContentAdapter()
        let config = CommunityConfig(
            documentationURL: "https://example.invalid/docs",
            supportURL: "https://example.invalid/support",
            discord: DiscordCard(
                title: "Community",
                inviteURL: "https://example.invalid/discord",
                memberCount: 42,
                isVisible: true
            ),
            registry: RegistryIndex(entries: [
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
                    isExperimental: true
                )
            ])
        )
        let skeleton = CommunitySheetSkeleton(
            state: .registryAvailable,
            visibleSections: [.discord, .documentation, .registry],
            selectedEntryId: "lab-kiro"
        )

        let descriptor = adapter.makeDescriptor(config: config, skeleton: skeleton)

        XCTAssertEqual(descriptor.state, .registryAvailable)
        XCTAssertEqual(descriptor.visibleSections, [.discord, .documentation, .registry])
        XCTAssertFalse(descriptor.requiresRegistryFetch)
        XCTAssertEqual(descriptor.documentationURL, "https://example.invalid/docs")
        XCTAssertEqual(descriptor.supportURL, "https://example.invalid/support")
        XCTAssertEqual(descriptor.discordTitle, "Community")
        XCTAssertEqual(descriptor.discordInviteURL, "https://example.invalid/discord")
        XCTAssertEqual(descriptor.discordMemberCount, 42)
        XCTAssertTrue(descriptor.isDiscordVisible)
        XCTAssertEqual(descriptor.registryEntryCount, 2)
        XCTAssertEqual(descriptor.experimentalRegistryEntryCount, 1)
        XCTAssertEqual(descriptor.selectedEntryId, "lab-kiro")
        XCTAssertEqual(descriptor.registryRows.map(\.id), ["theme-8bit", "lab-kiro"])
        XCTAssertEqual(descriptor.registryRows[1].authorDisplayName, "Lab Contributor")
        XCTAssertEqual(descriptor.registryRows[1].category, .labsTool)
        XCTAssertTrue(descriptor.registryRows[1].isExperimental)
        XCTAssertTrue(descriptor.registryRows[1].isSelected)
    }

    private func row(
        id: String,
        config: CommunityConfig,
        skeleton: CommunitySheetSkeleton
    ) -> CommunityContentAdapterMatrixRow {
        let descriptor = MyVibeIslandAppKitCommunityContentAdapter().makeDescriptor(
            config: config,
            skeleton: skeleton
        )

        return CommunityContentAdapterMatrixRow(
            id: id,
            state: descriptor.state.rawValue,
            visibleSections: descriptor.visibleSections.map(\.rawValue),
            requiresRegistryFetch: descriptor.requiresRegistryFetch,
            documentationURL: descriptor.documentationURL,
            supportURL: descriptor.supportURL,
            discordTitle: descriptor.discordTitle,
            discordInviteURL: descriptor.discordInviteURL,
            discordMemberCount: descriptor.discordMemberCount,
            isDiscordVisible: descriptor.isDiscordVisible,
            registryEntryCount: descriptor.registryEntryCount,
            experimentalRegistryEntryCount: descriptor.experimentalRegistryEntryCount,
            selectedEntryId: descriptor.selectedEntryId,
            registryRows: descriptor.registryRows.map(CommunityRegistryRowSummary.init)
        )
    }
}

private struct CommunityContentAdapterMatrixFixture: Codable, Equatable {
    let rows: [CommunityContentAdapterMatrixRow]
}

private struct CommunityContentAdapterMatrixRow: Codable, Equatable {
    let id: String
    let state: String
    let visibleSections: [String]
    let requiresRegistryFetch: Bool
    let documentationURL: String?
    let supportURL: String?
    let discordTitle: String?
    let discordInviteURL: String?
    let discordMemberCount: Int?
    let isDiscordVisible: Bool
    let registryEntryCount: Int
    let experimentalRegistryEntryCount: Int
    let selectedEntryId: String?
    let registryRows: [CommunityRegistryRowSummary]
}

private struct CommunityRegistryRowSummary: Codable, Equatable {
    let id: String
    let displayName: String
    let authorDisplayName: String
    let category: String
    let sourceURL: String?
    let isExperimental: Bool
    let isSelected: Bool

    init(_ row: MyVibeIslandAppKitCommunityRegistryRowDescriptor) {
        self.id = row.id
        self.displayName = row.displayName
        self.authorDisplayName = row.authorDisplayName
        self.category = row.category.rawValue
        self.sourceURL = row.sourceURL
        self.isExperimental = row.isExperimental
        self.isSelected = row.isSelected
    }
}
