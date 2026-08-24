import Darwin
import Foundation
import MyVibeIslandShared

public enum BridgeSocketPath {
    public static func defaultPath() -> String {
        defaultPath(processEnvironment: ProcessInfo.processInfo.environment)
    }

    public static func defaultPath(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> String {
        if let override = processEnvironment[BridgeRuntimeContract.socketEnvironmentVariable],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return BridgeRuntimeContract.defaultSocketPath(homeDirectory: homeDirectory)
    }

    public static func temporaryForTests() -> String {
        "/tmp/my-vibe-island-test-\(UUID().uuidString).sock"
    }
}
