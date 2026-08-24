public enum OriginalCompactPhysicalTitlePlan {
    public static func resolve(
        status: OriginalPixelStatusCompact,
        currentTool: String?,
        toolInput: [String: BridgeJSONValue]?,
        tasks: [TaskItem],
        todos: [TodoItem],
        repoName: String?,
        cwd: String?,
        source: String?
    ) -> OriginalCompactTitlePlan {
        switch status {
        case .thinking, .compacting:
            return plan(OriginalCompactTitleOverrides.resolve(for: status, mode: .physicalNotch)!)

        case .processing, .runningTool:
            guard let currentTool else {
                return OriginalCompactTitlePlan(
                    content: .localized(
                        key: "tool.workingEllipsis",
                        englishFallback: "Working...",
                        formatArgument: nil
                    )
                )
            }
            return plan(
                OriginalCompactPhysicalCurrentToolLabel.resolve(
                    currentTool: currentTool,
                    toolInput: toolInput
                ),
                transform: .physicalCompact
            )

        case .waitingForApproval:
            if let approval = OriginalCompactPhysicalApprovalLabel.resolve(
                status: status,
                currentTool: currentTool,
                toolInput: toolInput
            ) {
                return plan(approval, transform: .physicalCompact)
            }
            return activeWorkOrSessionPlan(
                tasks: tasks,
                todos: todos,
                repoName: repoName,
                cwd: cwd,
                source: source
            )

        case .waitingForInput, .question, .ended, .unknown:
            return activeWorkOrSessionPlan(
                tasks: tasks,
                todos: todos,
                repoName: repoName,
                cwd: cwd,
                source: source
            )
        }
    }

    private static func activeWorkOrSessionPlan(
        tasks: [TaskItem],
        todos: [TodoItem],
        repoName: String?,
        cwd: String?,
        source: String?
    ) -> OriginalCompactTitlePlan {
        let title = OriginalCompactActiveWorkTitle.resolve(tasks: tasks, todos: todos)
            ?? OriginalCompactSessionNameFallback.resolve(
                repoName: repoName,
                cwd: cwd,
                source: source
            )
        return OriginalCompactTitlePlan(content: .verbatim(title), transform: .physicalCompact)
    }

    private static func plan(
        _ title: OriginalCompactTitleOverrides.Title
    ) -> OriginalCompactTitlePlan {
        OriginalCompactTitlePlan(
            content: .localized(
                key: title.localizationKey,
                englishFallback: title.englishFallback,
                formatArgument: title.formatArgument
            )
        )
    }

    private static func plan(
        _ resolution: OriginalCompactToolVerb.Resolution,
        transform: OriginalCompactTitlePlan.PostLocalizationTransform
    ) -> OriginalCompactTitlePlan {
        let content: OriginalCompactTitlePlan.Content = switch resolution {
        case let .localized(key, englishFallback):
            .localized(key: key, englishFallback: englishFallback, formatArgument: nil)
        case let .verbatim(title):
            .verbatim(title)
        }
        return OriginalCompactTitlePlan(content: content, transform: transform)
    }

    private static func plan(
        _ resolution: OriginalCompactPhysicalApprovalLabel.Resolution,
        transform: OriginalCompactTitlePlan.PostLocalizationTransform
    ) -> OriginalCompactTitlePlan {
        let content: OriginalCompactTitlePlan.Content = switch resolution {
        case let .localized(key, englishFallback, formatArgument):
            .localized(
                key: key,
                englishFallback: englishFallback,
                formatArgument: formatArgument
            )
        case let .verbatim(title):
            .verbatim(title)
        }
        return OriginalCompactTitlePlan(content: content, transform: transform)
    }
}
