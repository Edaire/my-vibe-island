public enum OriginalCompactNonNotchedTitlePlan {
    public static func resolve(
        status: OriginalPixelStatusCompact,
        currentTool: String?,
        toolInput: [String: BridgeJSONValue]?,
        toolTarget: String?,
        repoName: String?,
        cwd: String?,
        source: String?,
        customTitle: String?,
        desktopTitle: String?,
        aiTitle: String?,
        summary: String?,
        normalizedFirstUserMessage: String?,
        normalizedLastUserMessage: String?
    ) -> OriginalCompactTitlePlan {
        switch status {
        case .thinking, .compacting:
            let override = OriginalCompactTitleOverrides.resolve(
                for: status,
                mode: .nonNotched,
                detail: toolTarget
            )!
            return localized(
                override.localizationKey,
                override.englishFallback,
                argument: override.formatArgument
            )

        case .processing, .runningTool:
            return toolPlan(
                currentTool: currentTool,
                toolInput: toolInput,
                toolTarget: toolTarget
            )

        case .waitingForApproval:
            if currentTool != nil {
                return toolPlan(
                    currentTool: currentTool,
                    toolInput: toolInput,
                    toolTarget: toolTarget
                )
            }
            return conversationPlan(
                repoName: repoName,
                cwd: cwd,
                source: source,
                customTitle: customTitle,
                desktopTitle: desktopTitle,
                aiTitle: aiTitle,
                summary: summary,
                normalizedFirstUserMessage: normalizedFirstUserMessage,
                normalizedLastUserMessage: normalizedLastUserMessage
            )

        case .waitingForInput, .question, .ended, .unknown:
            return conversationPlan(
                repoName: repoName,
                cwd: cwd,
                source: source,
                customTitle: customTitle,
                desktopTitle: desktopTitle,
                aiTitle: aiTitle,
                summary: summary,
                normalizedFirstUserMessage: normalizedFirstUserMessage,
                normalizedLastUserMessage: normalizedLastUserMessage
            )
        }
    }

    private static func toolPlan(
        currentTool: String?,
        toolInput: [String: BridgeJSONValue]?,
        toolTarget: String?
    ) -> OriginalCompactTitlePlan {
        if let currentTool {
            let detail = OriginalCompactToolDetail.resolve(
                currentTool: currentTool,
                toolInput: toolInput,
                toolTarget: toolTarget
            )
            return verbatim(detail.map { "\(currentTool): \($0)" } ?? currentTool)
        }

        if let toolTarget {
            let title = toolTarget.count > 30
                ? String(toolTarget.prefix(30)) + "..."
                : toolTarget
            return verbatim(title)
        }

        return localized("tool.workingEllipsis", "Working...", argument: nil)
    }

    private static func conversationPlan(
        repoName: String?,
        cwd: String?,
        source: String?,
        customTitle: String?,
        desktopTitle: String?,
        aiTitle: String?,
        summary: String?,
        normalizedFirstUserMessage: String?,
        normalizedLastUserMessage: String?
    ) -> OriginalCompactTitlePlan {
        let title = OriginalCompactConversationTitlePriority.resolve(
            customTitle: customTitle,
            desktopTitle: desktopTitle,
            aiTitle: aiTitle,
            summary: summary,
            normalizedFirstUserMessage: normalizedFirstUserMessage,
            normalizedLastUserMessage: normalizedLastUserMessage
        ) ?? OriginalCompactSessionNameFallback.resolve(
            repoName: repoName,
            cwd: cwd,
            source: source
        )
        return verbatim(title)
    }

    private static func localized(
        _ key: String,
        _ englishFallback: String,
        argument: String?
    ) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(
            content: .localized(
                key: key,
                englishFallback: englishFallback,
                formatArgument: argument
            ),
            transform: .none
        )
    }

    private static func verbatim(_ title: String) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(content: .verbatim(title), transform: .none)
    }
}
