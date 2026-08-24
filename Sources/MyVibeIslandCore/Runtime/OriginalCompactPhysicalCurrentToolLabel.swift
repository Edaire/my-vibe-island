public enum OriginalCompactPhysicalCurrentToolLabel {
    public static func resolve(
        currentTool: String,
        toolInput: [String: BridgeJSONValue]?
    ) -> OriginalCompactToolVerb.Resolution {
        if let label = OriginalCompactMCPToolLabel.resolve(currentTool) {
            return .verbatim(label)
        }

        if currentTool == "Skill" {
            guard let skill = toolInput?["skill"] else {
                return .localized(key: "tool.runningSkill", englishFallback: "Running Skill")
            }

            return .verbatim("Skill: \(OriginalToolInputValueProjection.resolve(skill))")
        }

        return OriginalCompactToolVerb.resolve(currentTool)
    }
}
