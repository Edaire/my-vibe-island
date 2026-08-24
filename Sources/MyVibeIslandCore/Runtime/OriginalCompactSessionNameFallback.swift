import Foundation

public enum OriginalCompactSessionNameFallback {
    public static func resolve(repoName: String?, cwd: String?, source: String?) -> String {
        if let repoName, !repoName.isEmpty {
            return repoName
        }

        if let cwd {
            return (cwd as NSString).lastPathComponent
        }

        return source == "cursor" ? "Cursor" : "Unknown"
    }
}
