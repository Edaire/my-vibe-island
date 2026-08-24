public enum NormalizedSessionContentPayload {
    public static func tasks(from payload: [String: BridgeJSONValue]) -> [TaskItem] {
        guard case let .array(values) = payload["tasks"] else {
            return []
        }

        return values.compactMap { value in
            guard case let .object(object) = value,
                  let id = string("id", in: object),
                  let subject = string("subject", in: object)
            else {
                return nil
            }

            return TaskItem(
                id: id,
                subject: subject,
                description: string("description", in: object),
                status: taskStatus(from: string("status", in: object)),
                activeForm: string("activeForm", in: object),
                blockedBy: string("blockedBy", in: object),
                owner: string("owner", in: object)
            )
        }
    }

    public static func todos(from payload: [String: BridgeJSONValue]) -> [TodoItem] {
        guard case let .array(values) = payload["todos"] else {
            return []
        }

        return values.compactMap { value in
            guard case let .object(object) = value,
                  let id = string("id", in: object),
                  let content = string("content", in: object)
            else {
                return nil
            }

            return TodoItem(
                id: id,
                content: content,
                status: todoStatus(from: string("status", in: object)),
                activeForm: string("activeForm", in: object)
            )
        }
    }

    private static func string(_ key: String, in object: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = object[key], !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func taskStatus(from rawValue: String?) -> TaskStatus {
        guard let rawValue else {
            return .unknown
        }

        return TaskStatus(rawValue: rawValue) ?? .unknown
    }

    private static func todoStatus(from rawValue: String?) -> TodoStatus {
        guard let rawValue else {
            return .unknown
        }

        return TodoStatus(rawValue: rawValue) ?? .unknown
    }
}
