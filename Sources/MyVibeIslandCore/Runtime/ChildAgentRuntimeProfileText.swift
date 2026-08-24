import Foundation

/// Matches V3's `AgentRuntimeProfile` projection used by `ChildAgentRow`.
/// The view passes the two AppStorage preferences into this formatter and
/// joins the admitted components with a middle dot.
public enum ChildAgentRuntimeProfileText {
    public static func resolve(
        model: String?,
        reasoningEffort: String?,
        showModel: Bool,
        showReasoningEffort: Bool
    ) -> String? {
        var components: [String] = []

        if showModel, let model = nonEmpty(model) {
            components.append(model)
        }
        if showReasoningEffort, let reasoningEffort = normalizedReasoningEffort(reasoningEffort) {
            components.append(reasoningEffort)
        }

        return components.isEmpty ? nil : components.joined(separator: " · ")
    }

    private static func normalizedReasoningEffort(_ value: String?) -> String? {
        guard let value = nonEmpty(value) else { return nil }

        switch value.lowercased() {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "xhigh": return "XHigh"
        case "max": return "Max"
        case "ultra": return "Ultra"
        default: return value
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
