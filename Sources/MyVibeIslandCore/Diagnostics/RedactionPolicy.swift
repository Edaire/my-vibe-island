import Foundation

public struct RedactionPolicy: Codable, Equatable, Sendable {
    public enum PathMode: String, Codable, Equatable, Sendable {
        case redactHomeDirectory
        case omit
    }

    public enum SecretMode: String, Codable, Equatable, Sendable {
        case redactKnownSensitiveFields
        case redactAllValues
    }

    public let pathMode: PathMode
    public let secretMode: SecretMode
    public let sensitiveFieldNames: [String]

    public init(
        pathMode: PathMode = .redactHomeDirectory,
        secretMode: SecretMode = .redactKnownSensitiveFields,
        sensitiveFieldNames: [String] = Self.defaultSensitiveFieldNames
    ) {
        self.pathMode = pathMode
        self.secretMode = secretMode
        self.sensitiveFieldNames = sensitiveFieldNames
    }

    public static let `default` = RedactionPolicy()

    public static let defaultSensitiveFieldNames = [
        "apiKey",
        "authorization",
        "credential",
        "password",
        "refreshToken",
        "secret",
        "session_token",
        "token",
        "accessToken"
    ]

    public func shouldRedactField(named fieldName: String) -> Bool {
        switch secretMode {
        case .redactAllValues:
            return true
        case .redactKnownSensitiveFields:
            let normalizedName = fieldName.lowercased()
            return sensitiveFieldNames.contains { $0.lowercased() == normalizedName }
        }
    }
}
