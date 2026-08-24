public enum OriginalCompactActiveWorkTitle {
    public static func resolve(tasks: [TaskItem], todos: [TodoItem]) -> String? {
        if let task = tasks.first(where: { $0.status == .active }) {
            return task.activeForm ?? task.subject
        }

        return todos.first(where: { $0.status == .active })?.activeForm
    }
}
