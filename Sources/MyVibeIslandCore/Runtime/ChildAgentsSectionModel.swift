public struct ChildAgentOverflow: Equatable, Sendable {
    public let runningCount: Int
    public let completedCount: Int

    public init(runningCount: Int = 0, completedCount: Int = 0) {
        self.runningCount = runningCount
        self.completedCount = completedCount
    }
}

/// V3 limits the task-child portion of a session card to five rows. Team
/// members are a separate V3 input collection and are intentionally not
/// synthesized from the local task-child ingress.
public struct ChildAgentsSectionModel: Equatable, Sendable {
    public static let maximumVisibleTaskSubagents = 5

    public let visibleTaskSubagents: [SubagentState]
    public let overflow: ChildAgentOverflow
    public let hiddenRunningCount: Int

    public static func resolve(
        taskSubagents: [SubagentState],
        showSubagents: Bool
    ) -> Self {
        guard showSubagents else {
            return Self(
                visibleTaskSubagents: [],
                overflow: ChildAgentOverflow(),
                hiddenRunningCount: taskSubagents.count(where: { !$0.isCompleted })
            )
        }

        // V3 composes non-completed task children before completed children,
        // retaining source order within each lifecycle group, then applies its
        // five-row card cap to that combined sequence.
        let orderedTaskSubagents = taskSubagents.filter { !$0.isCompleted }
            + taskSubagents.filter(\.isCompleted)
        let visibleTaskSubagents = Array(orderedTaskSubagents.prefix(maximumVisibleTaskSubagents))
        let overflow = orderedTaskSubagents.dropFirst(maximumVisibleTaskSubagents)
        return Self(
            visibleTaskSubagents: visibleTaskSubagents,
            overflow: ChildAgentOverflow(
                runningCount: overflow.count(where: { !$0.isCompleted }),
                completedCount: overflow.count(where: \.isCompleted)
            ),
            hiddenRunningCount: 0
        )
    }
}

private extension SubagentState {
    var isCompleted: Bool {
        status?.caseInsensitiveCompare("completed") == .orderedSame
    }
}
