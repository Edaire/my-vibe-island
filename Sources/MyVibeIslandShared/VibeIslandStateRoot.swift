import Foundation

public struct VibeIslandStateRoot: Equatable, Sendable {
    public static let stateHomeEnvironmentVariable = "MY_VIBE_ISLAND_STATE_HOME"

    public let homeDirectory: URL

    public init(homeDirectory: URL = runtimeHomeDirectory()) {
        self.homeDirectory = homeDirectory
    }

    /// LocalSignedDev capture runs can isolate all state under a disposable
    /// home without touching the user's production reconstruction state.
    public static func runtimeHomeDirectory(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        processArguments: [String] = CommandLine.arguments,
        fallback: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        guard let rawPath = stateHomeOverride(
            processEnvironment: processEnvironment,
            processArguments: processArguments
        )
        else {
            return fallback
        }

        return URL(fileURLWithPath: rawPath, isDirectory: true)
    }

    public static func isStateFixtureEnabled(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        processArguments: [String] = CommandLine.arguments
    ) -> Bool {
        stateHomeOverride(
            processEnvironment: processEnvironment,
            processArguments: processArguments
        ) != nil
    }

    private static func stateHomeOverride(
        processEnvironment: [String: String],
        processArguments: [String]
    ) -> String? {
        let environmentPath = processEnvironment[stateHomeEnvironmentVariable]
        let argumentPath = value(after: "--state-home", in: processArguments)
        return [environmentPath, argumentPath]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("/") }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex else { return nil }
        return arguments[next]
    }

    public var appSupportDir: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/MyVibeIsland")
    }

    public var sessionStoreURL: URL {
        appSupportDir.appendingPathComponent("sessions.json")
    }

    public var logsDir: URL {
        appSupportDir.appendingPathComponent("logs", isDirectory: true)
    }

    public var cacheDir: URL {
        appSupportDir.appendingPathComponent("cache", isDirectory: true)
    }

    public var gitIdentityCacheDir: URL {
        cacheDir.appendingPathComponent("git-identity", isDirectory: true)
    }

    public var admissionRulesURL: URL {
        appSupportDir.appendingPathComponent("admission-rules.json")
    }

    public var admissionRejectionsURL: URL {
        appSupportDir.appendingPathComponent("session-admission-rejections.json")
    }

    public var terminalSessionMapURL: URL {
        appSupportDir.appendingPathComponent("session-terminals.json")
    }

    public var legacyTerminalSessionMapURL: URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/vibe-island")
            .appendingPathComponent("session-terminals.json")
    }

    public var terminalSessionMapReadURLs: [URL] {
        [terminalSessionMapURL, legacyTerminalSessionMapURL]
    }
}
