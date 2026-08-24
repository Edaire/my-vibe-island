import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class OriginalExpandedHostingDescriptorAdapterTests: XCTestCase {
    func testAdapterUsesRootContentStatusInsteadOfPresentationIntent() throws {
        let session = session(id: "completion", cwd: "/work/completion")
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards, .notificationPeek],
            displayStatus: .notificationPeek,
            rootContentStatus: .expanded,
            displayReason: .notificationPeek,
            isPreviewingCompletionCard: true,
            completionPreviewSessionID: session.id,
            completionPreview: SessionCardPreview(session: session),
            completionPreviewSession: session,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            notificationSessionIds: [session.id]
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.sessionRows.map(\.id), [session.id])
        XCTAssertEqual(descriptor.contentPlan.completionBodyRowID, session.id)
        XCTAssertNil(descriptor.completionPreviewRow)
    }

    func testAdapterProjectsModelOwnedManualExpansionStateIntoTheRow() throws {
        let updatedAt = Date(timeIntervalSince1970: 100)
        let session = AgentSession(
            id: "old-warning",
            source: "codex",
            cwd: "/work/old-warning",
            originalStatus: .waitingForInput,
            updatedAt: updatedAt
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            manuallyExpandedSessionIDs: [session.id]
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )
        let row = try XCTUnwrap(descriptor.contentPlan.sessionRows.first)

        XCTAssertEqual(row.manuallyExpanded, true)
        XCTAssertEqual(row.statusWarning, true)
        XCTAssertEqual(row.dateAtOffset24, updatedAt)
    }

    func testAdapterUsesLastActivityAtForTheRecoveredCollapsedCardGate() throws {
        let lastActivityAt = Date(timeIntervalSince1970: 100)
        let warningSession = AgentSession(
            id: "warning-with-separate-activity-date",
            source: "codex",
            cwd: "/work/warning",
            originalStatus: .waitingForInput,
            updatedAt: Date(timeIntervalSince1970: 900),
            lastActivityAt: lastActivityAt
        )
        let rows = OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: nil,
            sessions: [
                session(id: "first", cwd: "/work/first"),
                warningSession,
                session(id: "third", cwd: "/work/third"),
                session(id: "fourth", cwd: "/work/fourth")
            ]
        )
        let row = try XCTUnwrap(rows[1])

        XCTAssertEqual(row.dateAtOffset24, lastActivityAt)
        XCTAssertEqual(
            OriginalSessionCardBranchSelector.resolve(
                derivedCollectionCount: rows.count,
                manuallyExpanded: row.manuallyExpanded,
                statusWarning: row.statusWarning,
                isFirst: false,
                dateAtOffset24: row.dateAtOffset24,
                now: Date(timeIntervalSince1970: 1_001),
                isCompletionPreview: false
            ),
            .horizontal
        )
    }

    func testAdapterProjectsKnownBranchEvidenceFromTheAuthoritativeSession() throws {
        let row = try XCTUnwrap(OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: nil,
            sessions: [session(id: "unresolved", cwd: "/work/unresolved")]
        ).first)

        XCTAssertEqual(row.manuallyExpanded, false)
        XCTAssertEqual(row.statusWarning, false)
        XCTAssertNil(row.dateAtOffset24)
    }

    func testProductionRowsKeepAnIneligibleCardInTheExpandedBranch() throws {
        let row = try XCTUnwrap(OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: nil,
            sessions: [session(id: "unresolved", cwd: "/work/unresolved")]
        ).first)

        XCTAssertEqual(
            OriginalSessionCardBranchSelector.resolve(
                derivedCollectionCount: 1,
                manuallyExpanded: row.manuallyExpanded,
                statusWarning: row.statusWarning,
                isFirst: true,
                dateAtOffset24: row.dateAtOffset24,
                now: Date(timeIntervalSince1970: 1_000),
                isCompletionPreview: false
            ),
            .vertical
        )
    }

    func testAdapterUsesNonCommercialEstimatedHeightBeforeLiveMeasurement() throws {
        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList(sessionCount: 3),
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.hostSize, DisplaySize(width: 680, height: 580))
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 640, height: 270))
    }

    func testAdapterUsesIDAEmptyExpandedFallbackHeight() throws {
        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList(sessionCount: 0),
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 640, height: 124))
    }

    func testVisiblePermissionRequestUsesTheCapturedApprovalViewportHeight() throws {
        let session = session(id: "approval", cwd: "/work/approval")
        let request = ActionRequestPreview(request: ActionableRequest(
            requestId: "permission-1",
            sessionId: session.id,
            source: "codex",
            kind: .permission,
            toolName: "Bash",
            details: ActionRequestDetails(command: "/usr/bin/whoami")
        ))
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards, .actionRequests],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            focusedSessionId: session.id,
            contentSize: DisplaySize(width: 680, height: 580),
            actionRequestPreviews: [request]
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        // The isolated real-Codex V3 capture has a 640 x 236 pixel approval
        // surface. The extra 38 points preserve the visible session-list
        // disclosure row below the approval actions.
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 640, height: 236))
    }

    func testAdapterPreservesTheExpandedUsageInfoBarForTheOriginalWaitingHeader() throws {
        let usageInfoBar = UsageInfoBar(
            status: .unavailable,
            title: "Codex",
            primaryText: "Usage unavailable",
            providerDisplayName: "Codex"
        )
        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: IslandSurfaceRenderList(sections: IslandSurfaceSections(
                    sessions: [session(id: "codex-waiting", cwd: "/private/tmp")],
                    visibleSections: [.compactPill, .expandedPanel, .sessionCards, .usageInfo],
                    displayStatus: .expanded,
                    layoutMode: .expanded,
                    onboardingStep: nil,
                    primarySessionIds: ["codex-waiting"],
                    focusedSessionId: "codex-waiting",
                    usageInfoBar: usageInfoBar
                )),
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.usageInfoBar, usageInfoBar)
    }

    func testAdapterDoesNotTreatFocusedSessionAsExpandedCardHighlight() throws {
        let sessions = (0..<3).map { index in
            AgentSession(
                id: "session-\(index)",
                source: "codex",
                cwd: "/work/project-\(index)",
                model: "gpt-5",
                originalStatus: .processing,
                repoName: "project-\(index)"
            )
        }
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions[1].id
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.sessionRows.map { $0.id }, sessions.map(\.id))
        XCTAssertEqual(
            descriptor.contentPlan.displayRows.map { $0.id },
            ["session-0", "session-1", "session-2"]
        )
        XCTAssertNil(descriptor.contentPlan.highlightedID)
        XCTAssertEqual(descriptor.surfaceSize.height, 270)
    }

    func testAdapterIntegratesCompletionPreviewIntoTheExpandedSessionList() throws {
        let sessions = [
            session(id: "active-1", cwd: "/work/one"),
            session(id: "completed", cwd: "/work/two"),
            session(id: "active-2", cwd: "/work/three")
        ]
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            displayReason: .notificationPeek,
            isPreviewingCompletionCard: true,
            completionPreviewSessionID: "completed",
            completionPreview: SessionCardPreview(session: sessions[1]),
            completionPreviewSession: sessions[1],
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            notificationSessionIds: ["completed"],
            focusedSessionId: "completed"
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.displayRows.map(\.id), ["completed", "active-1", "active-2"])
        XCTAssertEqual(descriptor.contentPlan.completionBodyRowID, "completed")
        XCTAssertNil(descriptor.completionPreviewRow)
    }

    func testAdapterKeepsTheCapturedCompletionPreviewWhenLiveRowsRefresh() throws {
        let captured = SessionCardPreview(session: AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/work/captured",
            safeTitle: "Captured completion title",
            originalStatus: .ended,
            lastAssistantMessage: "Captured assistant output"
        ))
        let capturedSession = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/work/captured",
            safeTitle: "Captured completion title",
            originalStatus: .ended,
            lastAssistantMessage: "Captured assistant output"
        )
        let refreshed = AgentSession(
            id: "completed",
            source: "codex",
            cwd: "/work/refreshed",
            safeTitle: "Live session after refresh",
            originalStatus: .processing,
            lastAssistantMessage: "Live assistant output after refresh"
        )
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [refreshed],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            displayReason: .notificationPeek,
            isPreviewingCompletionCard: true,
            completionPreviewSessionID: "completed",
            completionPreview: captured,
            completionPreviewSession: capturedSession,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: ["completed"],
            notificationSessionIds: ["completed"],
            focusedSessionId: "completed"
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.displayRows.first?.preview, captured)
        XCTAssertEqual(descriptor.contentPlan.displayRows.first?.expandedDisplayTitle, "Captured completion title")
        XCTAssertEqual(descriptor.contentPlan.displayRows.first?.session.lastAssistantMessage, "Captured assistant output")
        XCTAssertEqual(descriptor.contentPlan.completionBodyRowID, "completed")
        XCTAssertNil(descriptor.completionPreviewRow)
    }

    func testAdapterDoesNotInferCompletionPreviewFromNotificationReason() throws {
        let sessions = [session(id: "completed", cwd: "/work/two")]
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            displayReason: .notificationPeek,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            notificationSessionIds: ["completed"],
            focusedSessionId: "completed"
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertNil(descriptor.completionPreviewRow)
    }

    func testAdapterMarksExpandedDescriptorToShowAllSessionsWhenHovering() throws {
        let sessions = [
            session(id: "one", cwd: "/work/one"),
            session(id: "two", cwd: "/work/two")
        ]
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            isHovering: true,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions[0].id
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertTrue(descriptor.showsAllSessionRows)
    }

    func testExpandedContentDisplaysEveryEligibleRowWithoutReorderingFocusedSession() throws {
        let sessions = (0..<12).map { index in
            AgentSession(
                id: "session-\(index)",
                source: "codex",
                cwd: "/work/project-\(index)",
                originalStatus: .processing
            )
        }
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions[11].id
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertEqual(
            descriptor.contentPlan.displayRows.map(\.id),
            (0..<12).map { "session-\($0)" }
        )
        XCTAssertNil(descriptor.contentPlan.highlightedID)
    }

    func testDescriptorHeightUsesZeroOneThreeFourAndMoreThanFourSessions() throws {
        let expected: [(Int, Double)] = [(0, 124), (1, 126), (3, 270), (4, 342), (5, 342)]

        for (count, height) in expected {
            let descriptor = try XCTUnwrap(
                OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                    from: renderList(sessionCount: count),
                    screen: validScreen
                )
            )
            XCTAssertEqual(descriptor.surfaceSize.height, height, "count=\(count)")
        }
    }

    func testExpandedRowsCarryStatusForTheNonCommercialCardBody() throws {
        let session = AgentSession(
            id: "processing",
            source: "codex",
            cwd: "/work/project",
            activeTool: "apply_patch",
            activitySummary: "Updating the session card",
            originalStatus: .runningTool,
            repoName: "project"
        )
        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: IslandSurfaceRenderList(sections: IslandSurfaceSections(
                    sessions: [session],
                    visibleSections: [.compactPill, .expandedPanel, .sessionCards],
                    displayStatus: .expanded,
                    layoutMode: .expanded,
                    onboardingStep: nil,
                    primarySessionIds: [session.id]
                )),
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.sessionRows.first?.status, .runningTool)
        XCTAssertEqual(descriptor.contentPlan.sessionRows.first?.preview.activeTool, "apply_patch")
        XCTAssertEqual(
            descriptor.contentPlan.sessionRows.first?.preview.activitySummary,
            "Updating the session card"
        )
    }

    func testExpandedRowsPreferAuthoritativeSessionsOverStalePreviews() throws {
        let session = AgentSession(
            id: "authoritative",
            source: "codex",
            cwd: "/work/authoritative",
            model: "gpt-5.6",
            activeTool: "apply_patch",
            activitySummary: "Editing the real session",
            originalStatus: .runningTool,
            firstUserMessage: "Implement the real card",
            lastUserMessage: "Use the authoritative session",
            tasks: [TaskItem(id: "task-1", subject: "Render session", status: .active)]
        )
        let stalePreview = SessionCardPreview(session: AgentSession(
            id: session.id,
            source: "codex",
            cwd: "/work/stale",
            safeTitle: "stale preview"
        ))

        let row = try XCTUnwrap(OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: [stalePreview],
            sessions: [session]
        ).first)

        XCTAssertEqual(row.session, session)
        XCTAssertEqual(row.id, session.id)
        XCTAssertEqual(row.preview.localCwdDisplay, "authoritative")
        XCTAssertEqual(row.preview.activeTool, "apply_patch")
        XCTAssertEqual(row.taskSummary, "1/1 active tasks")
    }

    func testExpandedRowsDeduplicateDuplicateSessionIDsKeepingFirstOrder() {
        let first = session(id: "duplicate", cwd: "/first")
        let second = session(id: "duplicate", cwd: "/second")
        let third = session(id: "third", cwd: "/third")

        let rows = OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: nil,
            sessions: [first, second, third]
        )

        XCTAssertEqual(rows.map(\.id), ["duplicate", "third"])
        XCTAssertEqual(rows.first?.preview.localCwdDisplay, "first")
    }

    func testExpandedRowsDeduplicateDuplicatePreviewIDsKeepingFirstOrder() {
        let first = SessionCardPreview(session: session(id: "duplicate", cwd: "/first"))
        let second = SessionCardPreview(session: session(id: "duplicate", cwd: "/second"))
        let third = SessionCardPreview(session: session(id: "third", cwd: "/third"))

        let rows = OriginalExpandedHostingDescriptorAdapter.resolveSessionRows(
            previews: [first, second, third],
            sessions: []
        )

        XCTAssertEqual(rows.map(\.id), ["duplicate", "third"])
        XCTAssertEqual(rows.first?.preview.localCwdDisplay, "first")
    }

    func testAdapterUsesTheFullStoreSessionCollectionForExpandedSessionCards() throws {
        let visible = session(id: "visible", cwd: "/visible")
        let hidden = session(id: "hidden", cwd: "/hidden")
        let renderList = IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [visible, hidden],
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: [visible.id],
            focusedSessionId: visible.id
        ))

        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList,
                screen: validScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.sessionRows.map { $0.id }, [visible.id, hidden.id])
    }

    func testAdapterAcceptsMeasuredHeightInsteadOfEstimatedHeight() throws {
        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList(sessionCount: 3),
                screen: validScreen,
                measuredContentHeight: 123
            )
        )

        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 640, height: 163))
    }

    func testAdapterClampsLiveMeasurementOnlyAtExpandedMaximum() throws {
        let descriptor = try XCTUnwrap(
            OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
                from: renderList(sessionCount: 10),
                screen: validScreen,
                measuredContentHeight: 1_000
            )
        )

        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 640, height: 560))
    }

    func testAdapterRejectsNonExpandedAndInvalidScreenInputs() {
        XCTAssertNil(OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
            from: IslandSurfaceRenderList(sections: IslandSurfaceSections(
                visibleSections: [.compactPill],
                displayStatus: .closed
            )),
            screen: validScreen
        ))
        XCTAssertNil(OriginalExpandedHostingDescriptorAdapter.makeDescriptor(
            from: renderList(sessionCount: 1),
            screen: OriginalNSScreenMetricsInput(
                safeAreaTopInset: 32,
                frameWidth: 1512,
                auxiliaryTopLeftWidth: 663,
                auxiliaryTopRightWidth: 664
            )
        ))
    }

    private func renderList(sessionCount: Int) -> IslandSurfaceRenderList {
        let sessions = (0..<sessionCount).map { index in
            AgentSession(
                id: "session-\(index)",
                source: "codex",
                cwd: "/work/project-\(index)",
                originalStatus: .processing,
                repoName: "project-\(index)"
            )
        }
        return IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: sessionCount == 0
                ? [.compactPill, .expandedPanel]
                : [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions.first?.id,
            contentSize: DisplaySize(width: 680, height: 580)
        ))
    }

    private func session(id: String, cwd: String) -> AgentSession {
        AgentSession(
            id: id,
            source: "codex",
            cwd: cwd,
            originalStatus: .processing
        )
    }

    private var validScreen: OriginalNSScreenMetricsInput {
        OriginalNSScreenMetricsInput(
            safeAreaTopInset: 32,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664,
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 947)
        )
    }
}
