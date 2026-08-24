import Foundation
import MyVibeIslandShared

public enum AppRuntimeSessionStore {
    public static func defaultDirectory(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> URL {
        VibeIslandStateRoot(homeDirectory: homeDirectory).appSupportDir
    }

    public static func defaultFileURL(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> URL {
        VibeIslandStateRoot(homeDirectory: homeDirectory).sessionStoreURL
    }

    public static func defaultStore(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> JSONSessionStore {
        JSONSessionStore(fileURL: defaultFileURL(homeDirectory: homeDirectory))
    }

    public static func terminalSessionMapFileURLs(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> [URL] {
        VibeIslandStateRoot(homeDirectory: homeDirectory).terminalSessionMapReadURLs
    }

    public static func legacyTerminalSessionMapFileURLs(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> [URL] {
        [VibeIslandStateRoot(homeDirectory: homeDirectory).legacyTerminalSessionMapURL]
    }

    public static func runtime(
        socketPath: String = BridgeSocketPath.defaultPath(),
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory(),
        jumpRunner: TerminalJumpActionRunning? = nil,
        activeCliTTYs: @escaping @Sendable ([AgentSession]) -> Set<String> = { _ in [] },
        activeCodexSessions: @escaping @Sendable (SessionStore) -> [SessionState]? = { _ in nil },
        localWatcherHomeDirectory: URL? = nil
    ) -> AppRuntime {
        AppRuntime(
            socketPath: socketPath,
            sessionStore: defaultStore(homeDirectory: homeDirectory),
            jumpRunner: jumpRunner,
            activeCliTTYs: activeCliTTYs,
            activeCodexSessions: activeCodexSessions,
            localWatcherHomeDirectory: localWatcherHomeDirectory ?? homeDirectory
        )
    }
}
