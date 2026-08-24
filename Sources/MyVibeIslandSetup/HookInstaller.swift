import Foundation

public struct HookInstaller: Sendable {
    private let installer: SetupInstaller

    public init(installer: SetupInstaller = SetupInstaller()) {
        self.installer = installer
    }

    public func install(sourceId: String, homeDirectory: URL) throws -> SetupInstallResult {
        try installer.install(sourceId: sourceId, homeDirectory: homeDirectory)
    }
}
