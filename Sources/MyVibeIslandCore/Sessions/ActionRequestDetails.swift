public struct ActionRequestOption: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let detail: String?

    public init(id: String, label: String, detail: String? = nil) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct ActionRequestQuestion: Codable, Equatable, Sendable {
    public let id: String
    public let header: String
    public let prompt: String
    public let options: [ActionRequestOption]
    public let allowsMultipleSelection: Bool

    public init(
        id: String,
        header: String,
        prompt: String,
        options: [ActionRequestOption] = [],
        allowsMultipleSelection: Bool = false
    ) {
        self.id = id
        self.header = header
        self.prompt = prompt
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection
    }
}

public struct ActionRequestDetails: Codable, Equatable, Sendable {
    public let prompt: String?
    public let command: String?
    public let reason: String?
    public let options: [ActionRequestOption]
    public let allowsMultipleSelection: Bool
    public let questions: [ActionRequestQuestion]

    public init(
        prompt: String? = nil,
        command: String? = nil,
        reason: String? = nil,
        options: [ActionRequestOption] = [],
        allowsMultipleSelection: Bool = false,
        questions: [ActionRequestQuestion] = []
    ) {
        self.prompt = Self.nonEmpty(prompt)
        self.command = Self.nonEmpty(command)
        self.reason = Self.nonEmpty(reason)
        self.options = options
        self.allowsMultipleSelection = allowsMultipleSelection
        self.questions = questions
    }

    public static func safeDetails(
        from payload: [String: BridgeJSONValue],
        fallbackPrompt: String? = nil
    ) -> ActionRequestDetails? {
        let toolInput = object("tool_input", in: payload)
            ?? object("toolInput", in: payload)
            ?? [:]
        let questions = normalizedQuestions(
            from: payload["questions"] ?? toolInput["questions"]
        )
        let primaryQuestion = questions.first
        let command = string("command", in: payload)
            ?? string("command", in: toolInput)
        let reason = string("description", in: payload)
            ?? string("reason", in: payload)
            ?? string("description", in: toolInput)
            ?? string("reason", in: toolInput)
        let prompt = string("prompt", in: payload)
            ?? string("message", in: payload)
            ?? string("question", in: payload)
            ?? nonEmpty(fallbackPrompt)
            ?? primaryQuestion?.prompt
            ?? command
            ?? reason
        let topLevelOptions = normalizedOptions(from: payload["options"])
        let options = topLevelOptions.isEmpty
            ? (primaryQuestion?.options ?? [])
            : topLevelOptions
        let allowsMultipleSelection = bool("multiSelect", in: payload)
            ?? bool("multi", in: payload)
            ?? primaryQuestion?.allowsMultipleSelection
            ?? false

        guard prompt != nil || command != nil || reason != nil || !options.isEmpty || allowsMultipleSelection || !questions.isEmpty else {
            return nil
        }
        return ActionRequestDetails(
            prompt: prompt,
            command: command,
            reason: reason,
            options: options,
            allowsMultipleSelection: allowsMultipleSelection,
            questions: questions
        )
    }

    private static func normalizedQuestions(from value: BridgeJSONValue?) -> [ActionRequestQuestion] {
        guard case let .array(values) = value else {
            return []
        }

        return values.enumerated().compactMap { index, value in
            guard case let .object(object) = value,
                  let prompt = string("question", in: object) else {
                return nil
            }
            let header = string("header", in: object) ?? "Question \(index + 1)"
            return ActionRequestQuestion(
                id: string("id", in: object) ?? header,
                header: header,
                prompt: prompt,
                options: normalizedOptions(from: object["options"]),
                allowsMultipleSelection: bool("multiSelect", in: object)
                    ?? bool("multiple", in: object)
                    ?? false
            )
        }
    }

    private static func normalizedOptions(from value: BridgeJSONValue?) -> [ActionRequestOption] {
        guard case let .array(values) = value else {
            return []
        }

        return values.enumerated().compactMap { index, value in
            switch value {
            case let .string(label):
                guard let label = nonEmpty(label) else {
                    return nil
                }
                return ActionRequestOption(id: "option-\(index + 1)", label: label)
            case let .object(object):
                guard let label = string("label", in: object) else {
                    return nil
                }
                return ActionRequestOption(
                    id: string("id", in: object) ?? "option-\(index + 1)",
                    label: label,
                    detail: string("description", in: object)
                )
            case .bool, .integer, .number, .array, .null:
                return nil
            }
        }
    }

    private static func string(
        _ key: String,
        in object: [String: BridgeJSONValue]
    ) -> String? {
        guard case let .string(value) = object[key] else {
            return nil
        }
        return nonEmpty(value)
    }

    private static func bool(
        _ key: String,
        in object: [String: BridgeJSONValue]
    ) -> Bool? {
        guard case let .bool(value) = object[key] else {
            return nil
        }
        return value
    }

    private static func object(
        _ key: String,
        in object: [String: BridgeJSONValue]
    ) -> [String: BridgeJSONValue]? {
        guard case let .object(value) = object[key] else {
            return nil
        }
        return value
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
