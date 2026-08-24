import Foundation

public struct ClaudeCoworkAuditBlock: Codable, Equatable, Sendable {
    public let type: String
    public let text: String?
    public let name: String?
    public let input: BridgeJSONValue?

    public init(
        type: String,
        text: String? = nil,
        name: String? = nil,
        input: BridgeJSONValue? = nil
    ) {
        self.type = type
        self.text = text
        self.name = name
        self.input = input
    }
}

public struct ClaudeCoworkAuditContent: Codable, Equatable, Sendable {
    public let text: String?
    public let askQuestionInput: BridgeJSONValue?

    public init(text: String? = nil, askQuestionInput: BridgeJSONValue? = nil) {
        self.text = text
        self.askQuestionInput = askQuestionInput
    }

    public init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()
        if let text = try? singleValue.decode(String.self) {
            self.init(text: text)
            return
        }

        let blocks = try singleValue.decode([ClaudeCoworkAuditBlock].self)
        var text: String?
        var askQuestionInput: BridgeJSONValue?
        for block in blocks {
            if block.type == "text", let blockText = block.text, !blockText.isEmpty {
                text = blockText
            }
            if block.type == "tool_use", block.name == "AskUserQuestion" {
                askQuestionInput = block.input
            }
        }
        self.init(text: text, askQuestionInput: askQuestionInput)
    }
}

public struct ClaudeCoworkAuditMessage: Codable, Equatable, Sendable {
    public let role: String?
    public let content: ClaudeCoworkAuditContent

    public init(role: String? = nil, content: ClaudeCoworkAuditContent = ClaudeCoworkAuditContent()) {
        self.role = role
        self.content = content
    }
}

public struct ClaudeCoworkAuditRow: Codable, Equatable, Sendable {
    public let type: String
    public let message: ClaudeCoworkAuditMessage?
    public let result: String?
    public let isError: Bool?
    public let auditTimestamp: String?

    public init(
        type: String,
        message: ClaudeCoworkAuditMessage? = nil,
        result: String? = nil,
        isError: Bool? = nil,
        auditTimestamp: String? = nil
    ) {
        self.type = type
        self.message = message
        self.result = result
        self.isError = isError
        self.auditTimestamp = auditTimestamp
    }

    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
