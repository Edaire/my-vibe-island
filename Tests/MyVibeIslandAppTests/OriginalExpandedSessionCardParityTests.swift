import AppKit
import MyVibeIslandCore
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalExpandedSessionCardParityTests: XCTestCase {
    func testEligibleHorizontalCardTapTogglesModelOwnedManualExpansionBeforeJumpRouting() {
        XCTAssertEqual(
            OriginalExpandedSessionCardTapAction.resolve(
                manualExpansionEligible: true,
                jumpAvailable: true
            ),
            .toggleManualExpansion
        )
        XCTAssertEqual(
            OriginalExpandedSessionCardTapAction.resolve(
                manualExpansionEligible: false,
                jumpAvailable: true
            ),
            .jump
        )
    }

    func testManualCardExpansionUsesIDARecoveredTwoTenthsEaseInOutTransaction() {
        XCTAssertEqual(
            OriginalExpandedSessionCardTapMotion.resolve(for: .toggleManualExpansion),
            .easeInOut(duration: 0.2)
        )
        XCTAssertEqual(
            OriginalExpandedSessionCardTapMotion.resolve(for: .jump),
            .none
        )
    }

    func testCardPresentationProjectsSharedHeaderBodyAndCompletionInputFromOneRow() {
        let session = AgentSession(
            id: "shared-card",
            source: "codex",
            cwd: "/work/analysis",
            originalStatus: .ended,
            lastAssistantMessage: "The command completed.",
            firstUserMessage: "Run the verification.",
            lastUserMessage: "Show the final result.",
            hasUnreadCompletion: true
        )
        let row = OriginalExpandedSessionRow(session: session)

        let presentation = OriginalExpandedSessionCardPresentation.resolve(row: row)

        XCTAssertEqual(presentation.id, "shared-card")
        XCTAssertEqual(presentation.header.prompt, "Show the final result.")
        XCTAssertEqual(presentation.body.latestPrompt, "Show the final result.")
        XCTAssertEqual(presentation.completionAssistantMessage, "The command completed.")
        XCTAssertTrue(presentation.hasUnreadCompletion)
    }

    func testExpandedSessionTextUsesCapturedFourPointRowSpacing() {
        XCTAssertEqual(OriginalExpandedSessionLayoutPlan.original.contentSpacing, 4)
    }

    func testPendingPermissionUsesCapturedFivePointGapBelowItsSessionHeader() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(
            "VStack(alignment: .center, spacing: selectedPermissionRequest == nil ? 8 : 5)"
        ))
    }

    func testPermissionCardDoesNotPlaceApprovalButtonsUnderSessionTapGesture() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(
            "branchShell\n                .frame(minHeight: CGFloat(OriginalExpandedNonCommercialMeasurement.cardHeight))\n                .contentShape(Rectangle())\n                .onTapGesture"
        ))
        XCTAssertTrue(source.contains(
            ".contentShape(Rectangle())\n            .onTapGesture {\n                performTapAction()"
        ))
    }

    func testExpandedSessionListRendersEveryDisplayRowWithoutAnExplicitExpansion() {
        let rows = ["active", "history-1", "history-2"].map { id in
            OriginalExpandedSessionRow(session: AgentSession(
                id: id,
                source: "codex",
                cwd: "/work/\(id)",
                originalStatus: id == "active" ? .waitingForApproval : .ended
            ))
        }
        let contentPlan = OriginalExpandedContentPlan(
            sessionRows: rows,
            highlightedID: "active"
        )

        let visibility = OriginalExpandedSessionListVisibilityPlan.resolve(contentPlan: contentPlan)

        XCTAssertEqual(visibility.visibleRows.map(\.id), ["active", "history-1", "history-2"])
        XCTAssertEqual(visibility.hiddenSessionCount, 0)
        XCTAssertEqual(visibility.allSessionCount, 3)
        XCTAssertFalse(visibility.showsShowAllControl)
    }

    func testExpandedSessionListDoesNotNeedAnExpansionStateToKeepRowsVisible() {
        let rows = ["active", "history-1", "history-2"].map { id in
            OriginalExpandedSessionRow(session: AgentSession(
                id: id,
                source: "codex",
                cwd: "/work/\(id)",
                originalStatus: .processing
            ))
        }
        let contentPlan = OriginalExpandedContentPlan(
            sessionRows: rows,
            highlightedID: "active"
        )

        let visibility = OriginalExpandedSessionListVisibilityPlan.resolve(contentPlan: contentPlan)

        XCTAssertEqual(visibility.visibleRows.map(\.id), ["active", "history-1", "history-2"])
        XCTAssertEqual(visibility.hiddenSessionCount, 0)
        XCTAssertEqual(visibility.allSessionCount, 3)
        XCTAssertFalse(visibility.showsShowAllControl)
    }

    func testExpandedSessionListKeepsOrdinaryRenderRowsVisible() {
        let rows = ["active", "history-1", "history-2"].map { id in
            OriginalExpandedSessionRow(session: AgentSession(
                id: id,
                source: "codex",
                cwd: "/work/\(id)",
                originalStatus: .processing
            ))
        }
        let contentPlan = OriginalExpandedContentPlan(
            sessionRows: rows,
            highlightedID: "active"
        )

        let visibility = OriginalExpandedSessionListVisibilityPlan.resolve(contentPlan: contentPlan)

        XCTAssertEqual(visibility.visibleRows.map(\.id), ["active", "history-1", "history-2"])
        XCTAssertFalse(visibility.showsShowAllControl)
    }

    func testExpandedSessionListDoesNotContainAShowAllSessionsBranch() throws {
        let source = try String(contentsOf: expandedSessionsListSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("collapsesToHighlightedRow"))
        XCTAssertFalse(source.contains("显示全部"))
    }

    func testSessionCardUsesExtractedIDABackedSurface() throws {
        let cardSource = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let surfaceSource = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        XCTAssertTrue(cardSource.contains("OriginalExpandedSessionCardSurface("))
        for required in [
            ".padding(.horizontal, tokens.cardHorizontalInset)",
            "plan.axis == .horizontal ? 6 : tokens.cardVerticalInset",
            "RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)",
            ".stroke(color(stroke), lineWidth: 1)",
            ".animation(.easeInOut(duration: 0.15), value: animationValue)",
        ] {
            XCTAssertTrue(surfaceSource.contains(required), "Missing IDA-backed surface source: \(required)")
        }
    }

    func testVerticalSessionCardSurfaceDoesNotConsumeParentHeightDuringCompletionMeasurement() throws {
        let source = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        XCTAssertFalse(
            source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)"),
            "A vertically expanded card must keep its intrinsic completion viewport height; consuming its parent's proposed height feeds that measurement back into the root surface."
        )
    }

    func testVerticalBodySourceUsesDedicatedStatusAndContentColumns() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for required in [
            "private let layout = OriginalExpandedSessionLayoutPlan.original",
            "HStack(alignment: .center, spacing: CGFloat(layout.columnSpacing))",
            ".frame(width: CGFloat(layout.statusWidth), height: CGFloat(layout.statusHeight))",
            "VStack(alignment: .leading, spacing: CGFloat(layout.contentSpacing))",
            ".frame(maxWidth: .infinity, alignment: .leading)",
            "reservesHeaderControls: Bool = false",
            "statusIcon(status: presentation.body.status)",
            "completionHeader(presentation: presentation)",
            "private func completionBodyCard(",
        ] {
            XCTAssertTrue(source.contains(required), "Missing rebuilt column source: \(required)")
        }

        for forbidden in [
            "statusIconLeadingCompensation",
            ".frame(width: CGFloat(headerLayoutPlan.statusIconWidth), height: 12)",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Obsolete card positioning remains: \(forbidden)")
        }

        let statusIndex = try XCTUnwrap(source.range(of: "statusIcon(status: presentation.body.status)")?.lowerBound)
        let contentIndex = try XCTUnwrap(source.range(of: "VStack(alignment: .leading, spacing: CGFloat(layout.contentSpacing))")?.lowerBound)
        let headerIndex = try XCTUnwrap(source.range(of: "Text(header.title)")?.lowerBound)
        XCTAssertLessThan(statusIndex, contentIndex)
        XCTAssertLessThan(contentIndex, headerIndex)
    }

    func testProviderHeaderBadgesUseObservedProviderPalette() throws {
        let source = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("struct OriginalTagPill"))
        XCTAssertTrue(source.contains("enum OriginalTagPillPalette"))
        XCTAssertTrue(source.contains("case \"codex\": .codex"))
        XCTAssertTrue(source.contains("case \"claude\": .claude"))
        XCTAssertTrue(source.contains("Color.blue.opacity(0.9)"))
        XCTAssertTrue(source.contains("Color(red: 0.82, green: 0.36, blue: 0.16).opacity(0.95)"))
    }

    func testCollapsedHorizontalSessionRowsKeepTheCapturedLeadingStatusDot() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let horizontalBranch = try XCTUnwrap(source.range(of: "plan: .horizontalBranch"))
        let followingBranch = try XCTUnwrap(source.range(
            of: "case .vertical:",
            range: horizontalBranch.lowerBound..<source.endIndex
        ))
        let body = String(source[horizontalBranch.lowerBound..<followingBranch.lowerBound])

        XCTAssertTrue(body.contains("Circle()"))
        XCTAssertTrue(body.contains("frame(width: 6, height: 6)"))
        XCTAssertTrue(body.contains("headerBadge(header.sourceLabel, placeholder: \"Codex\")"))
        XCTAssertTrue(body.contains("headerBadge(header.terminalLabel, placeholder: \"tmux\")"))
        XCTAssertTrue(body.contains("headerBadge(header.ageLabel, placeholder: \"000m\")"))
    }

    func testActiveContentRendersToolLabelAndRealContentAsSeparateLines() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("if let activityToolLabel = descriptor.activityToolLabel"))
        XCTAssertTrue(source.contains("HStack(alignment: .firstTextBaseline, spacing: 6)"))
        XCTAssertTrue(source.contains("Text(activityToolLabel)"))
        XCTAssertTrue(source.contains("Text(activityContent)"))
        XCTAssertTrue(source.contains("Color.blue.opacity(0.9)"))
        XCTAssertTrue(source.contains("Color.white.opacity(0.72)"))
    }

    func testSessionCardTextAvoidsLowOpacityLabelsThatReadAsBlurred() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let completionHeader = try XCTUnwrap(source.range(of: "private func completionHeader"))
        let sessionHeader = try XCTUnwrap(source.range(of: "private func sessionHeader"))
        let completionContent = String(source[completionHeader.lowerBound..<sessionHeader.lowerBound])

        XCTAssertTrue(source.contains("Text(header.title)\n                    .font(.system(size: 12, weight: .semibold))\n                    .foregroundStyle(Color.white)"))
        XCTAssertTrue(source.contains("plan.segments.reduce(Text(\"\"))"))
        XCTAssertTrue(source.contains(".truncationMode(.tail)"))
        XCTAssertTrue(source.contains(".layoutPriority(1)"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        XCTAssertTrue(completionContent.contains("Text(\"你：\")\n                    .font(.system(size: contentFontSize, weight: .medium))\n                    .foregroundStyle(Color.white.opacity(0.82))"))
        XCTAssertTrue(completionContent.contains("Text(\"完成\")\n                .font(.system(size: contentFontSize, weight: .medium))\n                .foregroundStyle(Color.white.opacity(0.62))"))
        XCTAssertFalse(completionContent.contains("Color.white.opacity(0.50)"))
        XCTAssertFalse(completionContent.contains("Color.white.opacity(0.35)"))
    }

    func testHeaderTagsDoNotReserveObsoleteOverlayWidth() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(
            "reservesHeaderControls ? OriginalExpandedHeaderControlsView.reservedWidth + 8 : 0"
        ))
    }

    func testHeaderBadgesReserveStableColumnsWithoutAnObsoleteTerminalButtonHelper() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("headerBadge(header.sourceLabel, placeholder: \"Codex\")"))
        XCTAssertTrue(source.contains("headerBadge(header.terminalLabel, placeholder: \"tmux\")"))
        XCTAssertTrue(source.contains("headerBadge(header.ageLabel, placeholder: \"000m\")"))
        XCTAssertTrue(source.contains("private func headerBadge(_ value: String?, placeholder: String)"))
        XCTAssertTrue(source.contains("headerBadgeText(placeholder).hidden()"))
        XCTAssertFalse(source.contains("private func terminalJumpBadge"))
    }

    func testHeaderUsesIDACapturedTerminalJumpAffordanceWhenTheSessionCanJump() throws {
        let cardSource = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let componentSource = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        // IDA xrefs bind cursorarrow.click.2 to approval.goToTerminal, and the
        // original capture places that blue control after the age badge.
        XCTAssertTrue(cardSource.contains("if presentation.jumpAvailable {"))
        XCTAssertTrue(cardSource.contains("OriginalExpandedHeaderJumpControl {"))
        XCTAssertTrue(cardSource.contains("actions.jump(sessionID)"))
        XCTAssertTrue(componentSource.contains("Image(systemName: \"cursorarrow.click.2\")"))
    }

    func testAssistantViewportFillsTheLeadingContentColumn() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(
            "OriginalExpandedAssistantScrollView("
        ))
        XCTAssertTrue(source.contains(
            ".frame(maxWidth: .infinity, alignment: .leading)"
        ))
    }

    func testSessionHeaderFillsContentColumnBeforeAligningTags() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "private func sessionHeader"))
        let body = String(source[start.lowerBound..<source.endIndex])

        XCTAssertTrue(body.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
    }

    func testExpandedSessionListReservesHeaderControlRowOutsideScrollableContent() throws {
        let source = try String(contentsOf: expandedSessionsListSourceURL, encoding: .utf8)
        let bodyStart = try XCTUnwrap(source.range(of: "var body: some View"))
        let rowsStart = try XCTUnwrap(source.range(of: "private func sessionRows"))
        let body = String(source[bodyStart.lowerBound..<rowsStart.lowerBound])
        let rows = String(source[rowsStart.lowerBound..<source.endIndex])

        XCTAssertTrue(body.contains(".padding(.top, CGFloat(headerLayoutPlan.topInset))"))
        XCTAssertFalse(rows.contains(".padding(.top, CGFloat(headerLayoutPlan.topInset))"))
    }

    func testPassiveQuestionOptionsRenderTheirActualLabels() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(#"Text("• \(option.label)")"#))
        XCTAssertFalse(source.contains(#"Text("• (option.label)")"#))
    }

    func testMountedCompletedRowFitsExpandedWidthWithoutGrowingPastCompactViewport() {
        let host = NSHostingView(rootView: OriginalExpandedSessionCardView(
            row: completedPreviewRow(),
            isHighlighted: false,
            mountsCompletionBody: true
        ))
        host.frame = NSRect(x: 0, y: 0, width: 560, height: 1)
        host.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(host.fittingSize.width, 0)
        XCTAssertLessThanOrEqual(host.fittingSize.width, 560)
        XCTAssertGreaterThan(host.fittingSize.height, 0)
        XCTAssertLessThan(host.fittingSize.height, 200)
    }

    func testCompletionBodyUsesIndependentScrollableViewport() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let componentSource = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)
        XCTAssertFalse(source.contains("private var completionInteractionRegions"))
        XCTAssertFalse(source.contains(".frame(width: contentWidth, height: 52)"))

        let completionCard = try XCTUnwrap(source.range(of: "private func completionBodyCard("))
        let headerCall = try XCTUnwrap(
            source.range(of: "completionHeader(presentation: presentation)", range: completionCard.lowerBound..<source.endIndex)
        )
        let outputViewport = try XCTUnwrap(
            source.range(of: "OriginalExpandedAssistantScrollView(", range: headerCall.lowerBound..<source.endIndex)
        )
        let outputBackground = try XCTUnwrap(
            componentSource.range(of: "Color.white.opacity(tokens.completionViewportOpacity)")
        )

        XCTAssertLessThan(completionCard.lowerBound, headerCall.lowerBound)
        XCTAssertLessThan(headerCall.lowerBound, outputViewport.lowerBound)
        XCTAssertFalse(componentSource.isEmpty)
        XCTAssertNotNil(outputBackground)
    }

    func testCompletionCardUsesRecoveredSessionCardHierarchy() throws {
        let source = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        for required in [
            "VStack(alignment: .leading, spacing: 0)",
            ".padding(.horizontal, 8)",
            ".padding(.vertical, 7)",
            "Color.white.opacity(tokens.completionHeaderOpacity)",
            "Color.white.opacity(tokens.completionViewportOpacity)",
            "RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)",
            ".stroke(Color.white.opacity(tokens.completionHeaderOpacity), lineWidth: 1)",
        ] {
            XCTAssertTrue(source.contains(required), "Missing recovered completion layout: \(required)")
        }

        for forbidden in [
            "Color.white.opacity(0.18)",
            ".padding(.horizontal, 12)",
            ".padding(.horizontal, 14)",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Unsupported completion layout remains: \(forbidden)")
        }
    }

    func testCompletionOutputUsesRecoveredScrollableTextStyle() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "struct OriginalExpandedAssistantScrollView"))
        let end = try XCTUnwrap(source.range(of: "struct OriginalExpandedSessionCardView"))
        let outputView = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(outputView.contains("ScrollView(.vertical, showsIndicators: true)"))
        XCTAssertTrue(outputView.contains("design: .monospaced"))
        XCTAssertTrue(outputView.contains("Color.white.opacity(0.75)"))
        XCTAssertTrue(outputView.contains(".padding(8)"))
        XCTAssertFalse(outputView.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(outputView.contains("Text(message)\n                    .font(.system(size: contentFontSize, weight: .regular, design: .monospaced))\n                    .foregroundStyle(Color.white.opacity(0.75))\n                    .frame(maxWidth: .infinity, alignment: .topLeading)\n                    .fixedSize(horizontal: false, vertical: true)"))
    }

    func testCompletionNotificationDoesNotHaveSeparateSessionCardChrome() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("rendersBranchShellChrome"))
        XCTAssertFalse(source.contains("completionNotification"))
    }

    func testFocusedExpandedSessionPassesItsIDToTheIDARecoveredCardShell() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("highlightedID: isHighlighted ? row.id : nil"))
        XCTAssertFalse(source.contains("highlightedID: nil"))
    }

    func testSessionCardWiresIDARecoveredCardHoverToTheNamedHoverState() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(".onHover { isHovering in"))
        XCTAssertTrue(source.contains("isHovered = isHovering"))
    }

    func testApprovalButtonsWireTheSeparateV3ApprovalHoverState() throws {
        let cardSource = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let permissionSource = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)

        // V3 SessionCardView fields at offsets +0x20/+0x24 are respectively
        // `_isHovered` and `_isApprovalHovered`. The two approval-button
        // callback wrappers both enter sub_100789058, which writes the latter.
        XCTAssertTrue(cardSource.contains("@State private var isHovered = false"))
        XCTAssertTrue(cardSource.contains("@State private var isApprovalHovered = false"))
        XCTAssertTrue(cardSource.contains("onApprovalHoverChange: { isHovering in"))
        XCTAssertTrue(cardSource.contains("isApprovalHovered = isHovering"))
        XCTAssertTrue(permissionSource.contains("let onApprovalHoverChange: (Bool) -> Void"))
        XCTAssertTrue(permissionSource.contains(".onHover(perform: onApprovalHoverChange)"))
    }

    func testCompletionViewportUsesRecoveredLayeredSurfaceOpacities() throws {
        let source = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("completionHeaderOpacity: 0.10"))
        XCTAssertTrue(source.contains("completionViewportOpacity: 0.08"))
        XCTAssertFalse(source.contains("Color.white.opacity(0.18)"))
        XCTAssertFalse(source.contains("Color.white.opacity(0.055)"))
    }

    func testPermissionRequestUsesLiveOriginalLocalApprovalHierarchy() throws {
        let cardSource = try String(contentsOf: productionSourceURL, encoding: .utf8)
        let permissionSource = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)

        XCTAssertTrue(cardSource.contains("selectedPermissionRequest"))
        XCTAssertTrue(cardSource.contains("request.kind != .permission"))
        XCTAssertTrue(cardSource.contains("OriginalExpandedPermissionRequestCard("))
        XCTAssertTrue(cardSource.contains("onSubmit: onSubmitActionResolution"))
        XCTAssertTrue(permissionSource.contains("request.command ?? request.prompt ?? request.toolName"))
        XCTAssertTrue(permissionSource.contains("request.reason ?? \"请求需要在终端中确认\""))
        XCTAssertTrue(permissionSource.contains("Image(systemName: \"exclamationmark.triangle.fill\")"))
        XCTAssertTrue(permissionSource.contains("Text(\"在终端中审批\")"))
        XCTAssertTrue(permissionSource.contains("actionButton(\"拒绝\", kind: .deny"))
        XCTAssertTrue(permissionSource.contains("actionButton(\"允许一次\", kind: .approve"))
        XCTAssertTrue(permissionSource.contains("if request.canResolveLocally"))
    }

    func testPermissionRequestUsesCapturedApprovalHeaderAndCommandSurface() throws {
        let source = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)
        let componentSource = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("if !request.canResolveLocally"))
        XCTAssertTrue(source.contains("Text(\"允许\")"))
        XCTAssertTrue(source.contains("Text(request.toolName)"))
        XCTAssertTrue(source.contains("OriginalApprovalCommandSurface("))
        XCTAssertTrue(componentSource.contains("struct OriginalApprovalCommandSurface"))
        XCTAssertTrue(componentSource.contains("Text(\"$ \\(command)\")"))
        XCTAssertTrue(componentSource.contains("Color.orange.opacity(0.09)"))
        XCTAssertTrue(componentSource.contains("Color.orange.opacity(0.16)"))
    }

    func testPermissionRequestUsesCurrentOriginalLocalApprovalControls() throws {
        let source = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("OriginalLocalApprovalActionRow("))
        XCTAssertTrue(source.contains("onSubmit: onSubmit"))
        XCTAssertTrue(source.contains("actionButton(\"拒绝\", kind: .deny"))
        XCTAssertTrue(source.contains("actionButton(\"允许一次\", kind: .approve"))
        XCTAssertTrue(source.contains("Text(\"在终端中审批\")"))
        XCTAssertTrue(source.contains("if request.canResolveLocally"))
    }

    func testTerminalApprovalButtonHasAStableHitTargetAndTrace() throws {
        let source = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("approval.ui.jump_to_terminal_requested"))
        XCTAssertTrue(source.contains(".frame(minWidth: 92, minHeight: 22, alignment: .trailing)"))
        XCTAssertTrue(source.contains(".contentShape(Rectangle())"))
    }

    func testTerminalRoutedPermissionUsesOriginalTerminalHandoffInsteadOfLocalControls() throws {
        let source = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("if request.canResolveLocally"))
        XCTAssertTrue(source.contains("OriginalJumpToTerminalPill("))
        XCTAssertTrue(source.contains("toolName: request.toolName"))
        XCTAssertTrue(source.contains("command: command"))
        XCTAssertTrue(source.contains("action: onJumpToTerminal"))
    }

    func testTerminalHandoffUsesTheCapturedSixPointGapBelowTheCommandSurface() throws {
        let source = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("VStack(alignment: .leading, spacing: 6) {"))
    }

    func testPendingPermissionSuppressesTheOrdinaryActivityDetailLine() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("if selectedPermissionRequest == nil, !hideAgentDetailLine"))
    }

    func testPendingPermissionKeepsTheUserPromptToOneTruncatedLine() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(".lineLimit(selectedPermissionRequest == nil ? 1 : 2)"))
        XCTAssertTrue(source.contains(".lineLimit(1)\n                        .truncationMode(.tail)"))
    }

    func testTerminalHandoffRowUsesOriginalTwoLineContentAndSeparateRouteButton() throws {
        let source = try String(contentsOf: componentSystemSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("VStack(alignment: .leading, spacing: 2)"))
        XCTAssertTrue(source.contains("Text(\"请在终端中操作\")"))
        XCTAssertTrue(source.contains("Text(\"\\(toolName): \\(command)\")"))
        XCTAssertTrue(source.contains("Button(action: action)"))
        XCTAssertTrue(source.contains("Text(\"前往终端\")"))
        XCTAssertTrue(source.contains("HStack(spacing: 15)"))
        XCTAssertTrue(source.contains(".frame(width: 14)"))
        XCTAssertTrue(source.contains(".padding(.horizontal, 11)"))
        XCTAssertTrue(source.contains("minHeight: 53"))
    }

    func testTerminalHandoffRowMatchesCapturedFiftyThreePointHeight() {
        let height = fittingHeight(
            of: OriginalJumpToTerminalPill(
                toolName: "Bash",
                command: "/usr/bin/whoami",
                action: {}
            ),
            width: 600
        )

        XCTAssertEqual(height, 53, accuracy: 1)
    }

    func testMountedAssistantOutputSelfSizesShortContentAndCapsLongContent() {
        let shortHeight = fittingHeight(
            of: OriginalExpandedAssistantScrollView(
                message: "Short response",
                maximumHeight: 90
            ),
            width: 480
        )
        let longHeight = fittingHeight(
            of: OriginalExpandedAssistantScrollView(
                message: Array(repeating: "A complete assistant response line.", count: 20)
                    .joined(separator: "\n"),
                maximumHeight: 90
            ),
            width: 480
        )

        XCTAssertGreaterThan(shortHeight, 0)
        XCTAssertLessThan(shortHeight, 90)
        XCTAssertEqual(longHeight, 90, accuracy: 1)
    }

    func testMountedLongAssistantReplyHasScrollableInnerViewport() throws {
        let host = NSHostingView(rootView: OriginalExpandedAssistantScrollView(
            message: (1...40).map { "Assistant output line \($0)" }.joined(separator: "\n"),
            maximumHeight: 90
        ))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 90),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        host.frame = NSRect(x: 0, y: 0, width: 480, height: 90)
        window.contentView = host
        window.contentView?.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()

        let mountedViews = descendants(of: host)
        let scrollView = try XCTUnwrap(mountedViews.compactMap { $0 as? NSScrollView }.first)
        scrollView.layoutSubtreeIfNeeded()
        let documentHeight = try XCTUnwrap(scrollView.documentView?.frame.height)

        XCTAssertLessThanOrEqual(scrollView.frame.height, 90)
        XCTAssertGreaterThan(documentHeight, scrollView.contentView.bounds.height)
        XCTAssertTrue(scrollView.hasVerticalScroller)

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 24))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        XCTAssertGreaterThan(scrollView.contentView.bounds.origin.y, 0)
    }

    func testAssistantOutputSourceRemovesHeightFeedbackLoopAndUsesConfiguredDefaults() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        for forbidden in [
            "OriginalExpandedAssistantContentHeightKey",
            "@State private var contentHeight",
            "GeometryReader { geometry",
            ".textSelection(.enabled)",
        ] {
            XCTAssertFalse(source.contains(forbidden), "Forbidden production source: \(forbidden)")
        }

        for required in [
            "@AppStorage(\"contentFontSize\") private var contentFontSize = 11.0",
            "@AppStorage(\"completionCardMaxHeight\") private var completionCardMaxHeight = 90.0",
        ] {
            XCTAssertTrue(source.contains(required), "Missing production source: \(required)")
        }
    }

    func testAssistantViewportDoesNotAddAnUnsupportedAutomaticScrollReader() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        // Matching V3 has one ScrollViewReader/ScrollViewProxy.scrollTo path,
        // and it belongs to switcher highlighted-row centering. The completion
        // response viewport remains manually scrollable but is not a second
        // auto-scroll producer.
        XCTAssertFalse(source.contains("OriginalExpandedAssistantScrollPlan"))
        XCTAssertFalse(source.contains("ScrollViewReader { proxy in"))
        XCTAssertFalse(source.contains("assistant-message-bottom"))
        XCTAssertFalse(source.contains("proxy.scrollTo("))
        XCTAssertTrue(source.contains("ScrollView(.vertical, showsIndicators: true)"))
    }

    func testMountedCompletionBodyRequiresUnreadCompletionAndAssistantContent() {
        XCTAssertFalse(OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: true,
            status: .processing,
            hasUnreadCompletion: false,
            assistantMessage: "Current response"
        ))
        XCTAssertTrue(OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: true,
            status: .ended,
            hasUnreadCompletion: true,
            assistantMessage: "Completed response"
        ))
        XCTAssertFalse(OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: true,
            status: .ended,
            hasUnreadCompletion: true,
            assistantMessage: nil
        ))
        XCTAssertFalse(OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: false,
            status: .ended,
            hasUnreadCompletion: true,
            assistantMessage: "Completed response"
        ))
    }

    func testExpandedSessionCardDefaultsCompletionBodyToUnmounted() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(
            source.contains("mountsCompletionBody: Bool = false"),
            "Expanded session cards must default to the lightweight unmounted body"
        )
        XCTAssertFalse(OriginalExpandedCompletionBodyPlan.shouldRender(
            isMounted: false,
            status: .ended,
            hasUnreadCompletion: true,
            assistantMessage: "Completed response"
        ))
    }

    func testSessionCardUsesWholeCardTapOnlyForHorizontalRows() throws {
        let source = try String(contentsOf: productionSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("branchShell\n                .frame(minHeight:"))
        XCTAssertTrue(source.contains("case .horizontal:"))
        XCTAssertTrue(source.contains(".contentShape(Rectangle())\n            .onTapGesture {\n                performTapAction()"))
        XCTAssertFalse(source.contains("branchShell\n                .frame(minHeight: CGFloat(OriginalExpandedNonCommercialMeasurement.cardHeight))\n                .contentShape(Rectangle())\n                .onTapGesture"))
        XCTAssertFalse(source.contains("independentInteractionRegions"))
        XCTAssertFalse(source.contains("OriginalExpandedSessionCardInteractionRegionPlan"))
        XCTAssertFalse(source.contains("GeometryReader { proxy in"))
    }

    func testWholeCardTapPrefersJumpAndFallsBackToSelection() {
        var selected: [String] = []
        var jumped: [String] = []
        let actions = OriginalExpandedSessionCardActions(
            onSelectSession: { selected.append($0) },
            onJumpToSession: { jumped.append($0) }
        )

        XCTAssertEqual(
            OriginalExpandedSessionCardTapAction.resolve(jumpAvailable: true),
            .jump
        )
        XCTAssertEqual(
            OriginalExpandedSessionCardTapAction.resolve(jumpAvailable: false),
            .select
        )

        actions.perform(.jump, sessionID: "session-1")
        XCTAssertTrue(selected.isEmpty)
        XCTAssertEqual(jumped, ["session-1"])

        actions.perform(.select, sessionID: "session-1")
        XCTAssertEqual(selected, ["session-1"])
        XCTAssertEqual(jumped, ["session-1"])
    }

    func testExpandedHeaderDescriptorKeepsFirstConversationTitleAndLatestPrompt() {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/work/project",
            updatedAt: Date(timeIntervalSince1970: 9_970),
            firstUserMessage: "Start the project",
            lastUserMessage: "Show the current session",
            jumpInput: JumpInput(
                sessionId: "session-1",
                source: "codex",
                pid: 4617,
                isInTmux: true,
                tmuxPane: "%1"
            )
        )
        let row = OriginalExpandedSessionRow(session: session)

        let descriptor = OriginalExpandedSessionHeaderDescriptor.resolve(
            row: row,
            now: Date(timeIntervalSince1970: 10_000)
        )

        XCTAssertEqual(descriptor.title, "project · Start the project")
        XCTAssertEqual(descriptor.prompt, "Show the current session")
        XCTAssertEqual(descriptor.sourceLabel, "Codex")
        XCTAssertEqual(descriptor.terminalLabel, "tmux")
        XCTAssertEqual(descriptor.ageLabel, "<1m")
        XCTAssertNil(descriptor.processLabel)
    }

    func testExpandedHeaderDescriptorUsesResolvedTmuxIdentityWhenRawJumpInputIsAbsent() {
        let jumpInput = JumpInput(
            sessionId: "resolved-tmux",
            source: "codex",
            isInTmux: true,
            tmuxPane: "%9"
        )
        let session = AgentSession(
            id: "resolved-tmux",
            source: "codex",
            cwd: "/work/project",
            resolvedJumpTarget: TerminalResolver().resolve(jumpInput)
        )

        XCTAssertEqual(
            OriginalExpandedSessionHeaderDescriptor.resolve(
                row: OriginalExpandedSessionRow(session: session)
            ).terminalLabel,
            "tmux"
        )
    }

    func testExpandedHeaderLayoutReservesTheOriginalControlClearanceAboveTheFirstSession() {
        let root = OriginalRootSurfaceLayoutPlan.resolve(
            displayState: .expanded,
            isHovering: false,
            safeAreaTopInset: 0,
            leftStatusSlotWidth: 0,
            rightStatusSlotWidth: 0
        )

        let plan = OriginalExpandedHeaderLayoutPlan.resolve(rootLayoutPlan: root)

        XCTAssertEqual(
            plan.topInset,
            root.innerHorizontalBottomPadding
                + OriginalExpandedSessionLayoutPlan.original.controlFrame
                + OriginalExpandedSessionLayoutPlan.original.controlSpacing
        )
        XCTAssertEqual(plan.visualTopOffset, root.shape.topCornerRadius)
        XCTAssertEqual(
            plan.statusIconWidth,
            root.outerHorizontalInset + root.innerHorizontalBottomPadding
        )
        XCTAssertEqual(plan.statusIconLeadingCompensation, plan.statusIconWidth / 2)
        XCTAssertEqual(plan.rowSpacing, 8)
        XCTAssertEqual(plan.contentSpacing, 4)
    }

    func testHighlightedSessionAlwaysUsesTheRecoveredCenterScrollPath() throws {
        let source = try String(contentsOf: expandedSessionsListSourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("withAnimation(.easeOut(duration: duration))"))
        XCTAssertTrue(source.contains("proxy.scrollTo(id, anchor: .center)"))
        XCTAssertFalse(source.contains("preservesApprovalTopAnchor"))
    }

    func testApprovalRowKeepsLiveOriginalTextColumnAndLocalActionSeparation() throws {
        // In the captured original approval panel, the session text begins 49pt after
        // the status column origin (x=36 -> x=85). The live original then separates
        // its command surface from full-width local actions by 6pt.
        XCTAssertEqual(OriginalExpandedSessionLayoutPlan.original.statusWidth, 43)

        let permissionSource = try String(contentsOf: permissionRequestSourceURL, encoding: .utf8)
        XCTAssertTrue(permissionSource.contains("VStack(alignment: .leading, spacing: 12)"))
        XCTAssertTrue(permissionSource.contains("OriginalLocalApprovalActionRow("))
        XCTAssertTrue(permissionSource.contains("request: request,"))
        XCTAssertTrue(permissionSource.contains("onSubmit: onSubmit,"))
        XCTAssertTrue(permissionSource.contains("HStack(spacing: 6)"))
        XCTAssertTrue(permissionSource.contains(".frame(height: 26)"))
    }

    func testRendererProductionCallbacksForwardTypedValues() {
        var selected: [String] = []
        var jumped: [String] = []
        var resolutions: [ActionResolution] = []
        let renderer = MyVibeIslandAppKitOriginalUnifiedHostingRenderer(
            onNavigateSwitcher: { _ in },
            onSubmitSwitcher: {},
            onCollapseSwitcher: {},
            onRequestFocus: {},
            onReleaseFocus: {},
            onSelectSession: { selected.append($0) },
            onJumpToSession: { jumped.append($0) },
            onSubmitActionResolution: { resolutions.append($0); return true }
        )
        let resolution = ActionResolution(
            requestId: "request-1",
            sessionId: "session-1",
            kind: .approve
        )

        renderer.selectSession("session-1")
        renderer.jumpToSession("session-1")
        XCTAssertTrue(renderer.submitActionResolution(resolution))

        XCTAssertEqual(selected, ["session-1"])
        XCTAssertEqual(jumped, ["session-1"])
        XCTAssertEqual(resolutions, [resolution])
    }

    private func previewRow() -> OriginalExpandedSessionRow {
        let session = AgentSession(
            id: "session-1",
            source: "codex",
            cwd: "/work/project",
            safeTitle: "Project",
            originalStatus: .processing
        )
        return OriginalExpandedSessionRow(
            preview: SessionCardPreview(session: session),
            status: .processing
        )
    }

    private func completedPreviewRow() -> OriginalExpandedSessionRow {
        let session = AgentSession(
            id: "completed-session",
            source: "codex",
            cwd: "/work/project",
            activitySummary: "Completed",
            safeTitle: "Completed project",
            originalStatus: .ended,
            lastAssistantMessage: "The requested layout reconstruction is complete.",
            firstUserMessage: "Rebuild the expanded session row.",
            lastUserMessage: "Match the accepted original screenshot.",
            hasUnreadCompletion: true
        )
        return OriginalExpandedSessionRow(
            preview: SessionCardPreview(session: session),
            status: .ended
        )
    }

    private func actionRequest() -> ActionRequestPreview {
        ActionRequestPreview(request: ActionableRequest(
            requestId: "request-1",
            sessionId: "session-1",
            source: "opencode",
            kind: .question,
            toolName: "question",
            details: ActionRequestDetails(
                options: [ActionRequestOption(id: "one", label: "One")]
            )
        ))
    }

    private func fittingHeight<Content: View>(of view: Content, width: CGFloat) -> CGFloat {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    private var productionSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyVibeIslandApp/OriginalExpandedSessionCardView.swift")
    }

    private var surfaceSourceURL: URL {
        productionSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("OriginalExpandedSessionCardSurface.swift")
    }

    private var expandedSessionsListSourceURL: URL {
        productionSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("OriginalExpandedSessionsListView.swift")
    }

    private var permissionRequestSourceURL: URL {
        productionSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("OriginalExpandedPermissionRequestCard.swift")
    }

    private var componentSystemSourceURL: URL {
        productionSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("OriginalIslandComponentSystem.swift")
    }
}
