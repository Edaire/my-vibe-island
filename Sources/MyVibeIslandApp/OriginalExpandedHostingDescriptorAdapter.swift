import MyVibeIslandCore

enum OriginalExpandedHostingDescriptorAdapter {
    static func makeDescriptor(
        from renderList: IslandSurfaceRenderList,
        screen: OriginalNSScreenMetricsInput,
        measuredContentHeight: Double? = nil
    ) -> OriginalExpandedHostingDescriptor? {
        guard screen.hasValidDisplayFrames,
              renderList.sections.rootContentStatus == .expanded,
              renderList.sections.visibleSections.contains(.expandedPanel)
        else {
            return nil
        }

        let item = renderList.items.first { $0.section == .sessionCards }
        let authoritativeRows = resolveSessionRows(
            previews: item?.sessionPreviews,
            sessions: item?.sessions ?? [],
            manuallyExpandedSessionIDs: renderList.sections.manuallyExpandedSessionIDs
        )
        let capturedCompletionRow = completionPreviewRow(
            in: renderList,
            sessionRows: authoritativeRows
        )
        let sessionRows = integrating(
            capturedCompletionRow,
            into: authoritativeRows
        )
        let contentPlan = OriginalExpandedContentPlan(
            sessionRows: sessionRows,
            highlightedID: capturedCompletionRow?.id
        )
        let estimatedContentHeight = OriginalExpandedNonCommercialMeasurement.measuredContentHeight(
            sessionCount: contentPlan.displayRows.count
        )
        let hasVisiblePermissionRequest = renderList.sections.actionRequestPreviews.contains {
            $0.kind == .permission
        }
        let resolvedContentHeight: Double
        if hasVisiblePermissionRequest {
            resolvedContentHeight = OriginalExpandedNonCommercialMeasurement.collapsedPermissionContentHeight
        } else {
            // IDA's expanded resolver consumes the measured ScrollView content
            // directly and clamps only at maxExpandedHeight. The measurement
            // is the viewport/content contract, not a reason to cap the list
            // back to the four-row fallback estimate.
            resolvedContentHeight = measuredContentHeight ?? estimatedContentHeight
        }

        return OriginalExpandedHostingDescriptorBuilder.makeDescriptor(from: OriginalIslandGeometryInput(
            screenFrame: screen.screenFrame,
            visibleFrame: screen.visibleFrame,
            safeAreaTopInset: screen.safeAreaTopInset,
            displayState: .expanded,
            compactIntrinsicWidth: 0,
            measuredContentHeight: resolvedContentHeight,
            sessionCount: sessionRows.count,
            focusedSpecialSession: false,
            maxExpandedWidth: 640,
            maxExpandedHeight: 560
        ),
            contentPlan: contentPlan,
            completionPreviewRow: nil,
            usageInfoBar: renderList.sections.usageInfoBar,
            showsAllSessionRows: renderList.sections.isHovering
        )
    }

    static func resolveSessionRows(
        previews: [SessionCardPreview]?,
        sessions: [AgentSession],
        manuallyExpandedSessionIDs: Set<String> = []
    ) -> [OriginalExpandedSessionRow] {
        let authoritativeRows = unique(sessions, by: \.id).map { session in
            OriginalExpandedSessionRow(
                session: session,
                manuallyExpanded: manuallyExpandedSessionIDs.contains(session.id),
                statusWarning: session.originalStatus == .waitingForInput,
                dateAtOffset24: session.lastActivityAt
            )
        }
        guard authoritativeRows.isEmpty else { return authoritativeRows }
        return unique(previews ?? [], by: \.sessionId).map { OriginalExpandedSessionRow(preview: $0) }
    }

    private static func completionPreviewRow(
        in renderList: IslandSurfaceRenderList,
        sessionRows: [OriginalExpandedSessionRow]
    ) -> OriginalExpandedSessionRow? {
        guard renderList.sections.isPreviewingCompletionCard,
              let completionPreview = renderList.sections.completionPreview,
              let completionPreviewSession = renderList.sections.completionPreviewSession else {
            return nil
        }
        return OriginalExpandedSessionRow(
            session: completionPreviewSession,
            preview: completionPreview
        )
    }

    private static func integrating(
        _ completionRow: OriginalExpandedSessionRow?,
        into sessionRows: [OriginalExpandedSessionRow]
    ) -> [OriginalExpandedSessionRow] {
        guard let completionRow else { return sessionRows }
        guard let index = sessionRows.firstIndex(where: { $0.id == completionRow.id }) else {
            return [completionRow] + sessionRows
        }

        let existing = sessionRows[index]
        let integrated = OriginalExpandedSessionRow(
            session: completionRow.session,
            preview: completionRow.preview,
            status: completionRow.status,
            modelLabel: existing.modelLabel,
            repositoryLabel: existing.repositoryLabel,
            manuallyExpanded: existing.manuallyExpanded,
            statusWarning: existing.statusWarning,
            dateAtOffset24: completionRow.dateAtOffset24 ?? existing.dateAtOffset24,
            taskSummary: existing.taskSummary,
            todoSummary: existing.todoSummary,
            childAgentSummary: existing.childAgentSummary
        )
        var result = sessionRows
        result[index] = integrated
        return result
    }

    private static func unique<Value>(
        _ values: [Value],
        by id: (Value) -> String
    ) -> [Value] {
        var seen = Set<String>()
        return values.filter { seen.insert(id($0)).inserted }
    }
}
