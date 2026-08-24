import Foundation

public enum OttyPaneResolver {
    public static func resolveFocusedPaneIfCwdMatches(
        sessionPane: String?,
        cwd: String?,
        socket: String?
    ) -> String? {
        if let sessionPane = nonEmpty(sessionPane) {
            return sessionPane
        }
        guard nonEmpty(cwd) != nil, nonEmpty(socket) != nil else {
            return nil
        }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
