import XCTest
@testable import MyVibeIslandCore

final class SettingsWindowNavigationModelsTests: XCTestCase {
    func testSettingsWindowNavigationMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            SettingsWindowNavigationMatrixFixture.self,
            from: try FixtureLoader.data("settings/settings-window-navigation-matrix")
        )

        let controller = SettingsWindowController()
        let diagnosticsLink = SettingsDeepLink(
            section: .about,
            rowId: "export",
            highlightReason: .userRequested,
            actionHint: .openDiagnostics
        )
        let openPlan = controller.plan(.open(deepLink: diagnosticsLink), from: SettingsWindowState(searchQuery: "  old  "))
        let closePlan = controller.plan(.close, from: openPlan.nextState)

        let actual = SettingsWindowNavigationMatrixFixture(
            defaultSidebarSections: SettingsSection.defaultSidebarSections.map(\.rawValue),
            headers: [
                headerRow(section: .general),
                headerRow(section: .integrations),
                headerRow(section: .sound),
                headerRow(section: .labs),
                headerRow(section: .about),
            ],
            planRows: [
                planRow(id: "open-diagnostics-deeplink", plan: openPlan),
                planRow(id: "close-preserves-section", plan: closePlan),
                planRow(id: "reopen-preserves-section", plan: controller.plan(.reopen, from: closePlan.nextState)),
                planRow(
                    id: "select-about-clears-deeplink",
                    plan: controller.plan(.selectSection(.about), from: openPlan.nextState)
                ),
                planRow(
                    id: "select-unavailable-labs-ignored",
                    plan: controller.plan(
                        .selectSection(.labs),
                        from: SettingsWindowState(availableSections: [.general, .about], selectedSection: .general)
                    )
                ),
                planRow(
                    id: "search-trims-query",
                    plan: controller.plan(
                        .updateSearch("  hooks  "),
                        from: SettingsWindowState(isOpen: true, selectedSection: .shortcuts)
                    )
                ),
            ]
        )

        XCTAssertEqual(actual, expected)
    }

    func testSettingsSectionDefaultsMatchIDANoncommercialCaseOrder() {
        XCTAssertEqual(SettingsSection.defaultSidebarSections.map(\.rawValue), [
            "general",
            "integrations",
            "notifications",
            "display",
            "sound",
            "usage",
            "shortcuts",
            "sshRemote",
            "labs",
            "about",
        ])
        XCTAssertFalse(SettingsSection.defaultSidebarSections.map(\.rawValue).contains("pass"))
    }

    func testSettingsDeepLinkRoundTripsSectionRowAndActionHint() throws {
        let link = SettingsDeepLink(
            section: .integrations,
            rowId: "codex",
            highlightReason: .repairRequired,
            actionHint: .openDiagnostics
        )

        let decoded = try JSONDecoder().decode(SettingsDeepLink.self, from: try JSONEncoder().encode(link))

        XCTAssertEqual(decoded, link)
    }

    func testSettingsWindowControllerOpensDeepLinkAndPreservesSectionOnReopen() {
        let controller = SettingsWindowController()
        let link = SettingsDeepLink(section: .about, rowId: "export", highlightReason: .userRequested)

        let opened = controller.plan(.open(deepLink: link), from: SettingsWindowState())
        XCTAssertEqual(opened.action, .showWindow)
        XCTAssertTrue(opened.nextState.isOpen)
        XCTAssertEqual(opened.nextState.selectedSection, .about)
        XCTAssertEqual(opened.nextState.deepLink, link)

        let closed = controller.plan(.close, from: opened.nextState)
        XCTAssertFalse(closed.nextState.isOpen)
        XCTAssertEqual(closed.nextState.selectedSection, .about)

        let reopened = controller.plan(.reopen, from: closed.nextState)
        XCTAssertTrue(reopened.nextState.isOpen)
        XCTAssertEqual(reopened.nextState.selectedSection, .about)
    }

    func testSelectingUnavailableSectionIsIgnored() {
        let controller = SettingsWindowController()
        let state = SettingsWindowState(availableSections: [.general, .about], selectedSection: .general)

        let plan = controller.plan(.selectSection(.labs), from: state)

        XCTAssertEqual(plan.action, .ignoredUnavailableSection)
        XCTAssertEqual(plan.nextState, state)
    }

    func testSearchQueryIsTrimmedAndDoesNotChangeSelectedSection() {
        let controller = SettingsWindowController()
        let state = SettingsWindowState(isOpen: true, selectedSection: .shortcuts)

        let plan = controller.plan(.updateSearch("  hooks  "), from: state)

        XCTAssertEqual(plan.action, .updateSearch)
        XCTAssertEqual(plan.nextState.searchQuery, "hooks")
        XCTAssertEqual(plan.nextState.selectedSection, .shortcuts)
    }

    func testDetailHeaderProvidesSectionMetadata() {
        let header = SettingsDetailHeader(section: .sound)

        XCTAssertEqual(header.title, "Sound")
        XCTAssertEqual(header.iconName, "speaker.wave.2")
        XCTAssertNil(header.helpLink)
    }

    func testSettingsDetailHeaderStoredFieldsMatchIDAReflection() {
        let labels = Mirror(reflecting: SettingsDetailHeader(section: .general)).children.compactMap(\.label)

        XCTAssertEqual(labels, ["section"])
    }

    private func headerRow(section: SettingsSection) -> SettingsHeaderRow {
        let header = SettingsDetailHeader(section: section)
        return SettingsHeaderRow(
            section: section.rawValue,
            title: header.title,
            iconName: header.iconName,
            helpLink: header.helpLink
        )
    }

    private func planRow(
        id: String,
        plan: SettingsWindowControllerPlan
    ) -> SettingsWindowPlanRow {
        SettingsWindowPlanRow(
            id: id,
            action: plan.action.rawValue,
            state: plan.nextState.fixture
        )
    }

    private struct SettingsWindowNavigationMatrixFixture: Codable, Equatable {
        let defaultSidebarSections: [String]
        let headers: [SettingsHeaderRow]
        let planRows: [SettingsWindowPlanRow]
    }

    private struct SettingsHeaderRow: Codable, Equatable {
        let section: String
        let title: String
        let iconName: String
        let helpLink: String?
    }

    private struct SettingsWindowPlanRow: Codable, Equatable {
        let id: String
        let action: String
        let state: SettingsWindowStateFixture
    }

    fileprivate struct SettingsWindowStateFixture: Codable, Equatable {
        let isOpen: Bool
        let availableSections: [String]
        let selectedSection: String
        let detailTitle: String
        let deepLinkSection: String?
        let deepLinkRowId: String?
        let deepLinkHighlightReason: String?
        let deepLinkActionHint: String?
        let searchQuery: String
    }
}

private extension SettingsWindowState {
    var fixture: SettingsWindowNavigationModelsTests.SettingsWindowStateFixture {
        SettingsWindowNavigationModelsTests.SettingsWindowStateFixture(
            isOpen: isOpen,
            availableSections: availableSections.map(\.rawValue),
            selectedSection: selectedSection.rawValue,
            detailTitle: detailHeader.title,
            deepLinkSection: deepLink?.section.rawValue,
            deepLinkRowId: deepLink?.rowId,
            deepLinkHighlightReason: deepLink?.highlightReason?.rawValue,
            deepLinkActionHint: deepLink?.actionHint?.rawValue,
            searchQuery: searchQuery
        )
    }
}
