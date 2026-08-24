public enum OriginalCompactPhysicalApprovalLabel {
    public enum Resolution: Equatable, Sendable {
        case localized(key: String, englishFallback: String, formatArgument: String)
        case verbatim(String)
    }

    public static func resolve(
        status: OriginalPixelStatusCompact,
        currentTool: String?,
        toolInput: [String: BridgeJSONValue]?
    ) -> Resolution? {
        guard let currentTool else { return nil }

        let label: String
        if let mcpLabel = OriginalCompactMCPToolLabel.resolve(currentTool) {
            label = mcpLabel
        } else if currentTool == "Skill", let skill = toolInput?["skill"] {
            label = "/\(OriginalToolInputValueProjection.resolve(skill))"
        } else {
            label = currentTool
        }

        if status == .waitingForApproval {
            return .localized(
                key: "tool.allowPrefix",
                englishFallback: "Allow %@",
                formatArgument: label
            )
        }
        return .verbatim(label)
    }
}
