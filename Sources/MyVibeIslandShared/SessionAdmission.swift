import Foundation

public enum CwdAdmissionMatchType: String, Codable, CaseIterable, Sendable {
    case prefix
    case contains
    case equals
}

public struct CwdAdmissionRule: Codable, Hashable, Sendable {
    public var pattern: String
    public var matchType: CwdAdmissionMatchType
    public var displayName: String?
    public var reason: String?
    public var isEnabled: Bool

    public init(
        pattern: String,
        matchType: CwdAdmissionMatchType,
        displayName: String? = nil,
        reason: String? = nil,
        isEnabled: Bool = true
    ) {
        self.pattern = pattern
        self.matchType = matchType
        self.displayName = displayName
        self.reason = reason
        self.isEnabled = isEnabled
    }
}

public struct CwdAdmissionMatch: Equatable, Sendable {
    public var pattern: String
    public var matchType: CwdAdmissionMatchType
    public var displayName: String?
    public var reason: String?
    public var isBuiltIn: Bool

    public init(
        pattern: String,
        matchType: CwdAdmissionMatchType,
        displayName: String? = nil,
        reason: String? = nil,
        isBuiltIn: Bool = false
    ) {
        self.pattern = pattern
        self.matchType = matchType
        self.displayName = displayName
        self.reason = reason
        self.isBuiltIn = isBuiltIn
    }
}

public enum CwdAdmissionPolicy {
    public static var builtInDeniedCwdRules: [CwdAdmissionRule] {
        [
            CwdAdmissionRule(
                pattern: "ClaudeProbe",
                matchType: .contains,
                displayName: "ClaudeProbe",
                reason: "usage/status probe"
            ),
            CwdAdmissionRule(
                pattern: "Application Support/CodexBar",
                matchType: .contains,
                displayName: "CodexBar",
                reason: "official health-check probe"
            ),
        ]
    }

    public static func activeDeniedCwdPatterns(userRules: [CwdAdmissionRule]) -> [CwdAdmissionRule] {
        (builtInDeniedCwdRules + userRules).filter(\.isEnabled)
    }

    public static func matchDeniedCwd(
        _ cwd: String?,
        userRules: [CwdAdmissionRule] = []
    ) -> CwdAdmissionMatch? {
        guard let cwd, !cwd.isEmpty else { return nil }
        for rule in activeDeniedCwdPatterns(userRules: userRules) {
            guard matches(cwd, rule: rule) else { continue }
            return CwdAdmissionMatch(
                pattern: rule.pattern,
                matchType: rule.matchType,
                displayName: rule.displayName,
                reason: rule.reason,
                isBuiltIn: builtInDeniedCwdRules.contains(rule)
            )
        }
        return nil
    }

    public static func isDenied(_ cwd: String?) -> Bool {
        matchDeniedCwd(cwd) != nil
    }

    public static func loadUserDeniedCwdPatterns(from url: URL) -> [CwdAdmissionRule] {
        guard let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(PersistedSessionAdmissionRulesV1.self, from: data) else {
            return []
        }
        return rules.deniedCwdPatterns
    }

    private static func matches(_ cwd: String, rule: CwdAdmissionRule) -> Bool {
        guard !rule.pattern.isEmpty else { return false }
        switch rule.matchType {
        case .prefix:
            return cwd.hasPrefix(rule.pattern)
        case .contains:
            return cwd.contains(rule.pattern)
        case .equals:
            return cwd == rule.pattern
        }
    }
}

public struct AppBundleAdmissionRule: Codable, Hashable, Sendable {
    public var bundleId: String
    public var displayName: String?
    public var reason: String?
    public var isEnabled: Bool

    public var id: String { bundleId }

    public init(
        bundleId: String,
        displayName: String? = nil,
        reason: String? = nil,
        isEnabled: Bool = true
    ) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.reason = reason
        self.isEnabled = isEnabled
    }
}

public struct AppBundleAdmissionMatch: Equatable, Sendable {
    public var bundleId: String
    public var displayName: String?
    public var reason: String?
    public var isBuiltIn: Bool

    public init(
        bundleId: String,
        displayName: String? = nil,
        reason: String? = nil,
        isBuiltIn: Bool = false
    ) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.reason = reason
        self.isBuiltIn = isBuiltIn
    }
}

public enum AppBundleAdmissionPolicy {
    public static var codexBarBundleId: String { "com.openai.codex" }
    public static var builtInDeniedAncestorBundles: [AppBundleAdmissionRule] { [] }

    public static func activeDeniedAncestorBundles(userRules: [AppBundleAdmissionRule]) -> [AppBundleAdmissionRule] {
        (builtInDeniedAncestorBundles + userRules).filter(\.isEnabled)
    }

    public static func deniedAncestorBundleIds(userRules: [AppBundleAdmissionRule]) -> Set<String> {
        Set(activeDeniedAncestorBundles(userRules: userRules).map(\.bundleId))
    }

    public static func matchDeniedAncestorBundle(
        _ bundleId: String?,
        userRules: [AppBundleAdmissionRule] = []
    ) -> AppBundleAdmissionMatch? {
        guard let bundleId, !bundleId.isEmpty else { return nil }
        for rule in activeDeniedAncestorBundles(userRules: userRules) where rule.bundleId == bundleId {
            return AppBundleAdmissionMatch(
                bundleId: rule.bundleId,
                displayName: rule.displayName,
                reason: rule.reason,
                isBuiltIn: builtInDeniedAncestorBundles.contains(rule)
            )
        }
        return nil
    }

    public static func loadUserDeniedAncestorBundles(from url: URL) -> [AppBundleAdmissionRule] {
        guard let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(PersistedSessionAdmissionRulesV1.self, from: data) else {
            return []
        }
        return rules.deniedAncestorBundles
    }
}

public struct SessionAdmissionEvidence: Codable, Equatable, Sendable {
    public var cwd: String?
    public var bundleIdentifiers: [String]

    public init(cwd: String? = nil, bundleIdentifiers: [String] = []) {
        self.cwd = cwd
        self.bundleIdentifiers = bundleIdentifiers
    }
}

public enum SessionAdmissionRejection: Codable, Equatable, Sendable {
    case ancestorBundle(String)
    case cwd(String)

    public var description: String {
        switch self {
        case let .ancestorBundle(bundleId):
            return "ancestor bundle denied: \(bundleId)"
        case let .cwd(pattern):
            return "cwd denied: \(pattern)"
        }
    }
}

public enum SessionAdmissionEvaluator {
    public static func rejection(
        for evidence: SessionAdmissionEvidence,
        userBundleRules: [AppBundleAdmissionRule] = [],
        userCwdRules: [CwdAdmissionRule] = []
    ) -> SessionAdmissionRejection? {
        for bundleId in evidence.bundleIdentifiers {
            if let match = AppBundleAdmissionPolicy.matchDeniedAncestorBundle(bundleId, userRules: userBundleRules) {
                return .ancestorBundle(match.bundleId)
            }
        }
        if let match = CwdAdmissionPolicy.matchDeniedCwd(evidence.cwd, userRules: userCwdRules) {
            return .cwd(match.pattern)
        }
        return nil
    }
}

public struct PersistedSessionAdmissionRulesV1: Codable, Equatable, Sendable {
    public var version: Int
    public var deniedAncestorBundles: [AppBundleAdmissionRule]
    public var deniedCwdPatterns: [CwdAdmissionRule]

    public init(
        version: Int = 1,
        deniedAncestorBundles: [AppBundleAdmissionRule] = [],
        deniedCwdPatterns: [CwdAdmissionRule] = []
    ) {
        self.version = version
        self.deniedAncestorBundles = deniedAncestorBundles
        self.deniedCwdPatterns = deniedCwdPatterns
    }
}

public enum SessionAdmissionConfig {
    public static func configURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        VibeIslandStateRoot(homeDirectory: homeDirectory).admissionRulesURL
    }

    public static func load(from url: URL) -> PersistedSessionAdmissionRulesV1 {
        guard let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(PersistedSessionAdmissionRulesV1.self, from: data) else {
            return PersistedSessionAdmissionRulesV1()
        }
        return rules
    }

    public static func save(_ rules: PersistedSessionAdmissionRulesV1, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rules).write(to: url, options: .atomic)
    }
}

public struct PersistedSessionAdmissionRejection: Codable, Equatable, Sendable {
    public var evidence: SessionAdmissionEvidence
    public var rejectedAt: Date
    public var reason: String

    public var cwd: String? { evidence.cwd }
    public var bundleIdentifiers: [String] { evidence.bundleIdentifiers }

    public init(
        evidence: SessionAdmissionEvidence,
        rejectedAt: Date,
        reason: String
    ) {
        self.evidence = evidence
        self.rejectedAt = rejectedAt
        self.reason = reason
    }
}

public enum SessionAdmissionLedger {
    public static func defaultURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        VibeIslandStateRoot(homeDirectory: homeDirectory).admissionRejectionsURL
    }

    public static func load(
        from url: URL,
        now _: Date = Date()
    ) -> [String: PersistedSessionAdmissionRejection] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: PersistedSessionAdmissionRejection].self, from: data) else {
            return [:]
        }
        return entries
    }

    public static func save(
        _ entries: [String: PersistedSessionAdmissionRejection],
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: url, options: .atomic)
    }

    public static func record(
        sessionId: String?,
        evidence: SessionAdmissionEvidence,
        rejection: SessionAdmissionRejection,
        to url: URL,
        now: Date = Date()
    ) throws {
        guard let sessionId, !sessionId.isEmpty else { return }
        var entries = load(from: url, now: now)
        entries[sessionId] = PersistedSessionAdmissionRejection(
            evidence: evidence,
            rejectedAt: now,
            reason: rejection.description
        )
        try save(entries, to: url)
    }
}
