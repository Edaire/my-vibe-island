import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitIslandSurfaceAdapterTests: XCTestCase {
    func testIslandSurfaceAdapterMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            IslandSurfaceAdapterMatrixFixture.self,
            from: try AppFixtureLoader.data("app/island-surface-adapter-matrix")
        )
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let primary = IslandSurfaceSections(
            visibleSections: [.compactPill, .notificationPeek, .updatePill],
            primarySessionIds: ["active"],
            notificationSessionIds: ["done"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 640, height: 420),
            updatePill: UpdateAvailablePill(visible: true, label: "Update 2.0.0", action: .openUpdateWindow)
        )
        let allSections = IslandSurfaceSections(
            visibleSections: [.compactPill, .expandedPanel, .sessionCards, .notificationPeek, .usageInfo, .updatePill, .switcher, .onboardingGlow, .questionActions],
            onboardingStep: .permissions,
            primarySessionIds: ["active"],
            notificationSessionIds: ["done"],
            focusedSessionId: "active",
            usageInfoBar: UsageInfoBar(status: .available, title: "Codex", primaryText: "64% used", secondaryText: "Resets soon", providerDisplayName: "Codex"),
            updatePill: UpdateAvailablePill(visible: true, label: "Update", targetVersion: "2.0.0", installReady: true, action: .installAndRelaunch),
            questionSelectionCount: 1
        )
        let actual = IslandSurfaceAdapterMatrixFixture(rows: [
            row(id: "primary-descriptors", sections: primary, adapter: adapter),
            row(id: "empty-hidden", sections: IslandSurfaceSections(), adapter: adapter),
            row(id: "all-section-styles", sections: allSections, adapter: adapter)
        ])

        XCTAssertEqual(actual, expected)
    }

    func testAdapterBuildsStableAppKitIslandDescriptors() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill, .notificationPeek, .updatePill],
            primarySessionIds: ["active"],
            notificationSessionIds: ["done"],
            focusedSessionId: "active",
            contentSize: DisplaySize(width: 640, height: 420),
            updatePill: UpdateAvailablePill(visible: true, label: "Update 2.0.0", action: .openUpdateWindow)
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertTrue(descriptor.isVisible)
        XCTAssertEqual(descriptor.contentSize, DisplaySize(width: 640, height: 420))
        XCTAssertEqual(descriptor.items, [
            MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                section: .compactPill,
                accessibilityLabel: "Compact island",
                secondaryLabel: "1 session",
                sessionBadges: ["active"],
                sessionIds: ["active"],
                interactionHint: .toggleExpandedPanel,
                isInteractive: true
            ),
            MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                section: .notificationPeek,
                accessibilityLabel: "Notification peek",
                detailLabel: "Notification session: done",
                secondaryLabel: "1 session",
                sessionBadges: ["done"],
                sessionIds: ["done"],
                interactionHint: .openNotificationSession,
                isInteractive: true
            ),
            MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                section: .updatePill,
                accessibilityLabel: "Update 2.0.0",
                detailLabel: "Opens update window",
                secondaryLabel: "1 session",
                sessionBadges: ["active"],
                sessionIds: ["active"],
                interactionHint: .openUpdateWindow,
                isInteractive: true
            )
        ])
    }

    func testEmptyRenderListProducesHiddenDescriptor() {
        let descriptor = MyVibeIslandAppKitIslandSurfaceAdapter()
            .makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: IslandSurfaceSections()))

        XCTAssertFalse(descriptor.isVisible)
        XCTAssertEqual(descriptor.items, [])
    }

    func testAdapterAssignsStableSectionStyles() {
        let sections = IslandSurfaceSections(
            visibleSections: [
                .compactPill,
                .expandedPanel,
                .sessionCards,
                .notificationPeek,
                .usageInfo,
                .updatePill,
                .switcher,
                .onboardingGlow,
                .questionActions
            ],
            onboardingStep: .permissions,
            primarySessionIds: ["active"],
            notificationSessionIds: ["done"],
            focusedSessionId: "active",
            usageInfoBar: UsageInfoBar(status: .available, title: "Codex", providerDisplayName: "Codex"),
            updatePill: UpdateAvailablePill(visible: true, label: "Update", action: .openUpdateWindow),
            questionSelectionCount: 1
        )

        let descriptor = MyVibeIslandAppKitIslandSurfaceAdapter()
            .makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        let styles: [MyVibeIslandAppKitIslandSurfaceItemStyle] = descriptor.items.map(\.style)

        XCTAssertEqual(styles, [
            .compactPill,
            .expandedPanel,
            .sessionCard,
            .notificationPeek,
            .usageInfo,
            .updatePill,
            .switcher,
            .onboardingGlow,
            .questionAction
        ])
    }

    func testSectionStylesExposeStableTokens() {
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.compactPill.rawValue, "compact-pill")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.expandedPanel.rawValue, "expanded-panel")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.sessionCard.rawValue, "session-card")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.notificationPeek.rawValue, "notification-peek")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.usageInfo.rawValue, "usage-info")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.updatePill.rawValue, "update-pill")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.switcher.rawValue, "switcher")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.onboardingGlow.rawValue, "onboarding-glow")
        XCTAssertEqual(MyVibeIslandAppKitIslandSurfaceItemStyle.questionAction.rawValue, "question-action")
    }

    func testAdapterIncludesCompactPillRightSlotDetailLabel() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill],
            primarySessionIds: ["active"],
            rightSlotContent: .usageRing(
                UsageRingBadge(
                    status: .available,
                    title: "73% used",
                    percent: 73,
                    providerDisplayName: "Codex"
                )
            )
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(descriptor.items.first?.detailLabel, "Codex usage: 73% used (73%)")
    }

    func testAdapterIncludesUpdatePillVersionAndInstallReadinessDetailLabel() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.updatePill],
            updatePill: UpdateAvailablePill(
                visible: true,
                label: "Update 2.0.0",
                targetVersion: "2.0.0",
                installReady: true,
                action: .installAndRelaunch
            )
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(
            descriptor.items.first?.detailLabel,
            "Target version 2.0.0 - Ready to install - Installs and relaunches"
        )
    }

    func testAdapterIncludesCompactPillSessionStateRightSlotDetailLabels() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let details = [
            adapter.makeSurfaceDescriptor(
                from: IslandSurfaceRenderList(
                    sections: IslandSurfaceSections(
                        visibleSections: [.compactPill],
                        rightSlotContent: .waitingAction(count: 2)
                    )
                )
            ).items.first?.detailLabel,
            adapter.makeSurfaceDescriptor(
                from: IslandSurfaceRenderList(
                    sections: IslandSurfaceSections(
                        visibleSections: [.compactPill],
                        rightSlotContent: .unreadCompletion(count: 1)
                    )
                )
            ).items.first?.detailLabel,
            adapter.makeSurfaceDescriptor(
                from: IslandSurfaceRenderList(
                    sections: IslandSurfaceSections(
                        visibleSections: [.compactPill],
                        rightSlotContent: .activeCount(3)
                    )
                )
            ).items.first?.detailLabel
        ]

        XCTAssertEqual(details, [
            "2 waiting actions",
            "1 unread completion",
            "3 active sessions"
        ])
    }

    func testAdapterIncludesUsageInfoBarDetailLabel() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.usageInfo],
            usageInfoBar: UsageInfoBar(
                status: .available,
                title: "Codex",
                primaryText: "64% used",
                secondaryText: "Resets soon",
                providerDisplayName: "Codex"
            )
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(descriptor.items.first?.detailLabel, "Codex: 64% used - Resets soon")
    }

    func testAdapterIncludesNotificationPeekSessionDetailLabels() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let singular = adapter.makeSurfaceDescriptor(
            from: IslandSurfaceRenderList(
                sections: IslandSurfaceSections(
                    visibleSections: [.notificationPeek],
                    notificationSessionIds: ["done"]
                )
            )
        )
        let plural = adapter.makeSurfaceDescriptor(
            from: IslandSurfaceRenderList(
                sections: IslandSurfaceSections(
                    visibleSections: [.notificationPeek],
                    notificationSessionIds: ["done", "review"]
                )
            )
        )

        XCTAssertEqual(singular.items.first?.detailLabel, "Notification session: done")
        XCTAssertEqual(plural.items.first?.detailLabel, "Notification sessions: done, review")
    }

    func testAdapterOmitsUsageInfoTitleSeparatorWhenTitleIsEmpty() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.usageInfo],
            usageInfoBar: UsageInfoBar(
                status: .available,
                title: "",
                primaryText: "64% used",
                secondaryText: "Resets soon",
                providerDisplayName: "Codex"
            )
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(descriptor.items.first?.detailLabel, "64% used - Resets soon")
    }

    func testAdapterIncludesFocusedSessionDetailLabels() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.expandedPanel, .sessionCards, .switcher],
            primarySessionIds: ["active", "waiting"],
            focusedSessionId: "active"
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(descriptor.items.map(\.detailLabel), [
            "Focused session: active",
            "Focused session: active",
            "Focused session: active"
        ])
    }

    func testAdapterIncludesQuestionActionSelectionDetailLabels() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let singular = adapter.makeSurfaceDescriptor(
            from: IslandSurfaceRenderList(
                sections: IslandSurfaceSections(
                    visibleSections: [.questionActions],
                    questionSelectionCount: 1
                )
            )
        )
        let plural = adapter.makeSurfaceDescriptor(
            from: IslandSurfaceRenderList(
                sections: IslandSurfaceSections(
                    visibleSections: [.questionActions],
                    questionSelectionCount: 2
                )
            )
        )

        XCTAssertEqual(singular.items.first?.detailLabel, "1 selected question")
        XCTAssertEqual(plural.items.first?.detailLabel, "2 selected questions")
    }

    func testAdapterIncludesOnboardingStepDetailLabel() {
        let adapter = MyVibeIslandAppKitIslandSurfaceAdapter()
        let sections = IslandSurfaceSections(
            visibleSections: [.onboardingGlow],
            onboardingStep: .permissions
        )

        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))

        XCTAssertEqual(descriptor.items.first?.detailLabel, "Onboarding step: permissions")
    }

    private func row(
        id: String,
        sections: IslandSurfaceSections,
        adapter: MyVibeIslandAppKitIslandSurfaceAdapter
    ) -> IslandSurfaceAdapterMatrixRow {
        let descriptor = adapter.makeSurfaceDescriptor(from: IslandSurfaceRenderList(sections: sections))
        return IslandSurfaceAdapterMatrixRow(
            id: id,
            isVisible: descriptor.isVisible,
            width: descriptor.contentSize.width,
            height: descriptor.contentSize.height,
            items: descriptor.items.map(IslandSurfaceItemSummary.init)
        )
    }
}

private struct IslandSurfaceAdapterMatrixFixture: Codable, Equatable {
    let rows: [IslandSurfaceAdapterMatrixRow]
}

private struct IslandSurfaceAdapterMatrixRow: Codable, Equatable {
    let id: String
    let isVisible: Bool
    let width: Double
    let height: Double
    let items: [IslandSurfaceItemSummary]
}

private struct IslandSurfaceItemSummary: Codable, Equatable {
    let section: String
    let style: String
    let accessibilityLabel: String
    let detailLabel: String?
    let secondaryLabel: String?
    let sessionIds: [String]
    let interactionHint: String
    let isInteractive: Bool

    init(_ item: MyVibeIslandAppKitIslandSurfaceItemDescriptor) {
        self.section = item.section.rawValue
        self.style = item.style.rawValue
        self.accessibilityLabel = item.accessibilityLabel
        self.detailLabel = item.detailLabel
        self.secondaryLabel = item.secondaryLabel
        self.sessionIds = item.sessionIds
        self.interactionHint = item.interactionHint.rawValue
        self.isInteractive = item.isInteractive
    }
}
