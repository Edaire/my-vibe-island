import Foundation

public enum OriginalCompactToolDetail {
    public static func resolve(
        currentTool: String?,
        toolInput: [String: BridgeJSONValue]?,
        toolTarget: String?
    ) -> String? {
        guard let toolInput else { return toolTarget }

        if currentTool == "Bash", let value = toolInput["command"] {
            return truncated(OriginalToolInputValueProjection.resolve(value), limit: 30)
        }

        if currentTool == "WebSearch", let value = toolInput["query"] {
            return truncated(OriginalToolInputValueProjection.resolve(value), limit: 35)
        }

        if currentTool == "WebFetch", let value = toolInput["url"] {
            let projected = OriginalToolInputValueProjection.resolve(value)
            let detail: String
            if let url = URL(string: projected) {
                let path = url.path.isEmpty || url.path == "/" ? "" : url.path
                detail = (url.host ?? "") + path
            } else {
                detail = projected
            }
            return truncated(detail, limit: 35)
        }

        if currentTool == "Skill", let value = toolInput["skill"] {
            return "/" + OriginalToolInputValueProjection.resolve(value)
        }

        if let value = toolInput["file_path"] {
            return (OriginalToolInputValueProjection.resolve(value) as NSString).lastPathComponent
        }
        if let value = toolInput["path"] {
            return (OriginalToolInputValueProjection.resolve(value) as NSString).lastPathComponent
        }
        if let value = toolInput["pattern"] {
            return OriginalToolInputValueProjection.resolve(value)
        }
        return toolTarget
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        value.count > limit ? String(value.prefix(limit)) + "..." : value
    }
}
