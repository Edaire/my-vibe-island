import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class OriginalCompactHostingDescriptorTests: XCTestCase {
    func testAcceptedStatusAndLayoutMatrixUsesCurrentPhysicalGeometry() throws {
        let screen = currentScreen
        let cases: [(NotchDisplayStatus, NotchLayoutMode, OriginalNotchLayoutMode, Double)] = [
            (.closed, .compact, .compact, 239),
            (.opening, .compact, .compact, 239),
            (.closed, .regular, .normal, 385),
            (.opening, .regular, .normal, 385),
        ]

        for (status, layoutMode, expectedLayoutMode, expectedWidth) in cases {
            let descriptor = try XCTUnwrap(
                OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                    from: renderList(displayStatus: status, layoutMode: layoutMode),
                    screen: screen
                )
            )

            XCTAssertEqual(descriptor.displayClass, .physicalNotch)
            XCTAssertEqual(descriptor.layoutMode, expectedLayoutMode)
            XCTAssertEqual(descriptor.displayState, .compact)
            XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: expectedWidth, height: 33))
            XCTAssertEqual(descriptor.compactLayoutPlan.centerNotchWidth, 185)
        }
    }

    func testMapsAuthoritativeSessionsDespiteLegacyContentSize() throws {
        let session = AgentSession(
            id: "authoritative",
            source: "codex",
            cwd: "/work/authoritative",
            activeTool: "Read",
            originalStatus: .runningTool,
            toolInput: ["file_path": .string("Sources/Authoritative.swift")],
            repoName: "authoritative-repo"
        )

        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(
                    contentSize: DisplaySize(width: 999, height: 777),
                    sessions: [session]
                ),
                screen: currentScreen
            )
        )
        let expectedContentPlan = OriginalCompactContentPlan.resolve(
            displayClass: .physicalNotch,
            sessions: [OriginalCompactSessionAdapter.resolve(session)]
        )

        XCTAssertEqual(descriptor.contentPlan, expectedContentPlan)
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 239, height: 33))
        XCTAssertEqual(descriptor.compactLayoutPlan.statusRegionWidth, 36)
        XCTAssertEqual(descriptor.compactLayoutPlan.rightRegionWidth, 18)
    }

    func testCompactPromotesRunningSessionsAheadOfRestoredEndedHistory() throws {
        let ended = AgentSession(
            id: "ended-history",
            source: "codex",
            cwd: "/work/old",
            originalStatus: .ended,
            repoName: "old"
        )
        let running = AgentSession(
            id: "running-now",
            source: "codex",
            cwd: "/work/current",
            activeTool: "Read",
            originalStatus: .runningTool,
            repoName: "current"
        )

        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(sessions: [ended, running]),
                screen: currentScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.status, .runningTool)
        XCTAssertEqual(descriptor.sessionInputs.map(\.status), [.runningTool, .ended])
        XCTAssertEqual(descriptor.contentPlan.status, .runningTool)
    }

    func testCompactUsesOriginalStatusRankForItsPrimarySession() throws {
        let thinking = AgentSession(
            id: "thinking",
            source: "codex",
            cwd: "/work/thinking",
            originalStatus: .thinking,
            updatedAt: Date(timeIntervalSinceReferenceDate: 300)
        )
        let approval = AgentSession(
            id: "approval",
            source: "codex",
            cwd: "/work/approval",
            originalStatus: .waitingForApproval,
            updatedAt: Date(timeIntervalSinceReferenceDate: 100)
        )

        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(sessions: [thinking, approval]),
                screen: currentScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.status, .waitingForApproval)
        XCTAssertEqual(descriptor.sessionInputs.map(\.status), [.waitingForApproval, .thinking])
    }

    func testCompactKeepsRightCountForTheFirstSortedDisplaySession() throws {
        let first = AgentSession(
            id: "running-a",
            source: "codex",
            cwd: "/work/a",
            activeTool: "Read",
            originalStatus: .runningTool,
            repoName: "a"
        )
        let second = AgentSession(
            id: "running-b",
            source: "codex",
            cwd: "/work/b",
            activeTool: "Bash",
            originalStatus: .processing,
            repoName: "b"
        )

        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(sessions: [first, second]),
                screen: currentScreen
            )
        )

        XCTAssertEqual(descriptor.contentPlan.status, .runningTool)
        XCTAssertEqual(descriptor.contentPlan.rightCount?.source, .sessions)
    }

    func testCompactDescriptorDoesNotExposeASecondSessionRotationPath() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalCompactHostingDescriptor.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("rotatingSessionInputs"))
        XCTAssertFalse(source.contains("contentPlan(for:"))
    }

    func testPhysicalRootHeightUsesCompactScreenMetricsHelperAndIgnoresLegacyContentSize() throws {
        let screen = OriginalNSScreenMetricsInput(
            safeAreaTopInset: 32,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664,
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 949)
        )
        let cases: [(notchHeightOffset: Double, legacyContentHeight: Double, expectedRootHeight: Double)] = [
            (4, 777, 37),
            (4, 1, 37),
            (-30, 333, 8),
        ]

        for testCase in cases {
            let descriptor = try XCTUnwrap(
                OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                    from: renderList(
                        runtimeState: OriginalCompactRuntimeState(
                            notchHeightOffset: testCase.notchHeightOffset
                        ),
                        contentSize: DisplaySize(width: 999, height: testCase.legacyContentHeight)
                    ),
                    screen: screen
                )
            )

            XCTAssertEqual(descriptor.surfaceSize.height, testCase.expectedRootHeight)
        }
    }

    func testPropagatesUnreadCompletionOverviewIntoCompactRightPresentation() throws {
        let runtimeState = OriginalCompactRuntimeState(
            isMinimized: true,
            notchWidthOffset: 5,
            notchHeightOffset: 3,
            completionFlashTick: 17
        )
        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(
                    runtimeState: runtimeState,
                    isHovering: true,
                    showsUnreadCompletionOverview: true
                ),
                screen: currentScreen
            )
        )

        XCTAssertTrue(descriptor.isMinimized)
        XCTAssertEqual(descriptor.completionFlashTick, 17)
        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 234, height: 36))
        XCTAssertEqual(descriptor.compactLayoutPlan.statusRegionWidth, 22)
        XCTAssertEqual(descriptor.compactLayoutPlan.centerNotchWidth, 190)
        XCTAssertEqual(descriptor.compactLayoutPlan.rightRegionWidth, 22)
        XCTAssertEqual(
            descriptor.rightPresentationPlan,
            OriginalCompactRightPresentationPlan.resolve(
                rightCount: descriptor.contentPlan.rightCount,
                usesCompactArrangement: true,
                showsUnreadCompletionOverview: true
            )
        )
        XCTAssertEqual(
            descriptor.rootLayoutPlan,
            OriginalRootSurfaceLayoutPlan.resolve(
                displayState: .compact,
                isHovering: true,
                safeAreaTopInset: 32,
                leftStatusSlotWidth: 22,
                rightStatusSlotWidth: 22
            )
        )
    }

    func testNonNotchedClosedUsesFrozenWidthBudgetsWithMinimizedTakingPriority() throws {
        let cases: [(NotchLayoutMode, Bool, Double)] = [
            (.compact, true, 154),
            (.regular, true, 154),
            (.compact, false, 206),
            (.regular, false, 340),
        ]

        for (layoutMode, isMinimized, expectedWidth) in cases {
            let descriptor = try XCTUnwrap(
                OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                    from: renderList(
                        runtimeState: OriginalCompactRuntimeState(isMinimized: isMinimized),
                        layoutMode: layoutMode
                    ),
                    screen: nonNotchedScreen(menuBarGap: 30)
                )
            )

            XCTAssertEqual(descriptor.displayClass, .nonNotched)
            XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: expectedWidth, height: 30))
            XCTAssertEqual(descriptor.compactLayoutPlan.statusRegionWidth, isMinimized ? 28 : layoutMode == .compact ? 36 : 60)
            XCTAssertNil(descriptor.compactLayoutPlan.centerNotchWidth)
            XCTAssertNil(descriptor.compactLayoutPlan.rightRegionWidth)
            XCTAssertEqual(descriptor.rootLayoutPlan.physicalHorizontalOffset, 0)
        }
    }

    func testNonNotchedClosedAppliesWidthOffsetAndClamp() throws {
        let cases: [(Double, Double)] = [(5, 211), (-200, 60)]

        for (notchWidthOffset, expectedWidth) in cases {
            let descriptor = try XCTUnwrap(
                OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                    from: renderList(runtimeState: OriginalCompactRuntimeState(
                        notchWidthOffset: notchWidthOffset
                    )),
                    screen: nonNotchedScreen(menuBarGap: 30)
                )
            )

            XCTAssertEqual(descriptor.surfaceSize.width, expectedWidth)
        }
    }

    func testNonNotchedClosedUsesMenuBarGapFloorHeightOffsetAndClamp() throws {
        let cases: [(Double, Double, Double)] = [
            (10, 0, 24),
            (30, 0, 30),
            (30, 4, 34),
            (30, -40, 8),
        ]

        for (menuBarGap, notchHeightOffset, expectedHeight) in cases {
            let descriptor = try XCTUnwrap(
                OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                    from: renderList(runtimeState: OriginalCompactRuntimeState(
                        notchHeightOffset: notchHeightOffset
                    )),
                    screen: nonNotchedScreen(menuBarGap: menuBarGap)
                )
            )

            XCTAssertEqual(descriptor.surfaceSize.height, expectedHeight)
        }
    }

    func testNonNotchedCurrentClosedCompactSurfaceIs206By30AndUsesNonNotchedPlans() throws {
        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(),
                screen: nonNotchedScreen(menuBarGap: 30)
            )
        )
        let expectedContentPlan = OriginalCompactContentPlan.resolve(
            displayClass: .nonNotched,
            sessions: renderList().items[0].sessions.map(OriginalCompactSessionAdapter.resolve)
        )

        XCTAssertEqual(descriptor.surfaceSize, DisplaySize(width: 206, height: 30))
        XCTAssertEqual(descriptor.displayClass, .nonNotched)
        XCTAssertEqual(descriptor.contentPlan, expectedContentPlan)
        XCTAssertTrue(descriptor.compactLayoutPlan.titleFlexesToMaximumWidth)
        XCTAssertEqual(descriptor.rootLayoutPlan.physicalHorizontalOffset, 0)
    }

    func testNonNotchedRejectsOpeningWhilePhysicalStillAcceptsIt() throws {
        XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList(displayStatus: .opening),
            screen: nonNotchedScreen(menuBarGap: 30)
        ))
        XCTAssertNotNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList(displayStatus: .opening),
            screen: currentScreen
        ))
    }

    func testNonNotchedRequiresExplicitValidDisplayFrames() {
        let screens = [
            OriginalNSScreenMetricsInput(
                safeAreaTopInset: 0,
                frameWidth: 1920,
                auxiliaryTopLeftWidth: 0,
                auxiliaryTopRightWidth: 0
            ),
            OriginalNSScreenMetricsInput(
                safeAreaTopInset: 0,
                frameWidth: 1920,
                auxiliaryTopLeftWidth: 0,
                auxiliaryTopRightWidth: 0,
                screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 0),
                visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 0)
            ),
            OriginalNSScreenMetricsInput(
                safeAreaTopInset: 0,
                frameWidth: 1920,
                auxiliaryTopLeftWidth: 0,
                auxiliaryTopRightWidth: 0,
                screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1090)
            ),
        ]

        for screen in screens {
            XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(),
                screen: screen
            ))
        }
    }

    func testRejectsMissingScreen() throws {
        let renderList = renderList()

        XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList,
            screen: nil
        ))
    }

    func testRequiresCompactPillAndAllowsUsageSupplement() throws {
        XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList(sections: []),
            screen: currentScreen
        ))
        XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList(sections: [.expandedPanel]),
            screen: currentScreen
        ))
        XCTAssertNotNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList(sections: [.compactPill, .usageInfo]),
            screen: currentScreen
        ))
    }

    func testRejectsEveryUnsupportedDisplayStatus() throws {
        for status in [
            NotchDisplayStatus.expanded,
            .notificationPeek,
            .switcher,
            .onboarding,
            .hidden,
            .autoHidden,
        ] {
            XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(displayStatus: status),
                screen: currentScreen
            ))
        }
    }

    func testRejectsCompactDescriptorWhenRootContentIsExpanded() {
        let sections = IslandSurfaceSections(
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            rootContentStatus: .expanded,
            layoutMode: .expanded,
            primarySessionIds: ["session-1"]
        )

        XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: IslandSurfaceRenderList(sections: sections),
            screen: currentScreen
        ))
    }

    func testRejectsExpandedLayoutMode() throws {
        XCTAssertNil(OriginalCompactHostingDescriptorBuilder.makeDescriptor(
            from: renderList(layoutMode: .expanded),
            screen: currentScreen
        ))
    }

    func testScreenInputAndDescriptorAreEquatableAndSendable() throws {
        let screen = currentScreen
        let descriptor = try XCTUnwrap(
            OriginalCompactHostingDescriptorBuilder.makeDescriptor(
                from: renderList(),
                screen: screen
            )
        )

        requireSendable(screen)
        requireSendable(descriptor)
        XCTAssertEqual(screen, currentScreen)
        XCTAssertEqual(descriptor, descriptor)
    }
}

private let currentScreen = OriginalNSScreenMetricsInput(
    safeAreaTopInset: 32,
    frameWidth: 1512,
    auxiliaryTopLeftWidth: 663,
    auxiliaryTopRightWidth: 664,
    screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
    visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 949)
)

private func nonNotchedScreen(menuBarGap: Double) -> OriginalNSScreenMetricsInput {
    OriginalNSScreenMetricsInput(
        safeAreaTopInset: 0,
        frameWidth: 1920,
        auxiliaryTopLeftWidth: 0,
        auxiliaryTopRightWidth: 0,
        screenFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: DisplayFrame(x: 0, y: 0, width: 1920, height: 1080 - menuBarGap)
    )
}

private func renderList(
    sections: [IslandSurfaceSection] = [.compactPill],
    runtimeState: OriginalCompactRuntimeState = OriginalCompactRuntimeState(),
    displayStatus: NotchDisplayStatus = .closed,
    layoutMode: NotchLayoutMode = .compact,
    isHovering: Bool = false,
    showsUnreadCompletionOverview: Bool = false,
    contentSize: DisplaySize = DisplaySize(width: 264, height: 36),
    sessions: [AgentSession] = [
        AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/work/project",
            originalStatus: .processing,
            repoName: "project"
        ),
    ]
) -> IslandSurfaceRenderList {
    let surfaceSections = IslandSurfaceSections(
        sessions: sessions,
        visibleSections: sections,
        originalCompactRuntimeState: runtimeState,
        displayStatus: displayStatus,
        layoutMode: layoutMode,
        isHovering: isHovering,
        isCompletionUnreadOverviewVisible: showsUnreadCompletionOverview,
        onboardingStep: nil,
        primarySessionIds: sessions.map(\.id),
        contentSize: contentSize,
    )
    return IslandSurfaceRenderList(sections: surfaceSections)
}

private func requireSendable<T: Sendable>(_: T) {}
