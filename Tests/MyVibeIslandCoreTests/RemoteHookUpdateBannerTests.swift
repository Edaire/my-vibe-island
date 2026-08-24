import XCTest
@testable import MyVibeIslandCore

final class RemoteHookUpdateBannerTests: XCTestCase {
    func testHookUpdateBannerMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            RemoteHookUpdateBannerMatrixFixture.self,
            from: try FixtureLoader.data("remote/hook-update-banner-matrix")
        )

        let actual = RemoteHookUpdateBannerMatrixFixture(rows: [
            row(
                id: "reported-hook-version-outdated",
                banner: RemoteHookUpdateBanner(
                    host: Self.outdatedHost(
                        id: "devbox",
                        alias: "devbox",
                        hookVersion: "1.0.0",
                        lastSetupVersion: "0.9.0"
                    ),
                    supportedHookVersion: "1.2.0"
                )
            ),
            row(
                id: "fallback-last-setup-version",
                banner: RemoteHookUpdateBanner(
                    host: Self.outdatedHost(
                        id: "fallback",
                        alias: "fallback",
                        hookVersion: nil,
                        lastSetupVersion: "1.1.0"
                    ),
                    supportedHookVersion: "1.2.0"
                )
            ),
            row(
                id: "absent-when-no-update",
                banner: RemoteHookUpdateBanner(
                    host: Self.currentHost,
                    supportedHookVersion: "1.2.0"
                )
            ),
        ])

        XCTAssertEqual(actual, expected)
    }

    func testHookUpdateBannerBuildsRedeployActionForOutdatedHost() throws {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/remote.sock",
            localSocketPath: "/tmp/local.sock",
            deployed: true,
            lastSetupVersion: "1.0.0",
            trustStatus: "trusted",
            hookVersion: "1.0.0",
            hookUpdateAvailable: true
        )

        let banner = RemoteHookUpdateBanner(host: host, supportedHookVersion: "1.2.0")
        let decoded = try JSONDecoder().decode(RemoteHookUpdateBanner.self, from: try JSONEncoder().encode(banner))

        XCTAssertEqual(decoded, banner)
        XCTAssertEqual(banner?.hostId, "devbox")
        XCTAssertEqual(banner?.currentHookVersion, "1.0.0")
        XCTAssertEqual(banner?.supportedHookVersion, "1.2.0")
        XCTAssertEqual(banner?.repairAction, .redeployHelper)
        XCTAssertEqual(banner?.redeployCommandPreview, "scp my-vibe-island-hooks devbox:~/.local/bin/my-vibe-island-hooks")
    }

    func testHookUpdateBannerIsAbsentWhenHostDoesNotReportUpdate() {
        let host = SSHHostStoreHost(
            id: "devbox",
            hostAlias: "devbox",
            hostName: "devbox.example.com",
            user: "dev",
            port: 22,
            tunnelKind: .tcp,
            tcpPort: 49152,
            deployed: true,
            trustStatus: "trusted",
            hookVersion: "1.2.0",
            hookUpdateAvailable: false
        )

        XCTAssertNil(RemoteHookUpdateBanner(host: host, supportedHookVersion: "1.2.0"))
    }

    private static let currentHost = SSHHostStoreHost(
        id: "devbox",
        hostAlias: "devbox",
        hostName: "devbox.example.com",
        user: "dev",
        port: 22,
        tunnelKind: .tcp,
        tcpPort: 49152,
        deployed: true,
        trustStatus: "trusted",
        hookVersion: "1.2.0",
        hookUpdateAvailable: false
    )

    private static func outdatedHost(
        id: String,
        alias: String,
        hookVersion: String?,
        lastSetupVersion: String?
    ) -> SSHHostStoreHost {
        SSHHostStoreHost(
            id: id,
            hostAlias: alias,
            hostName: "\(alias).example.com",
            user: "dev",
            port: 22,
            tunnelKind: .uds,
            remoteSocketPath: "/tmp/\(alias)-remote.sock",
            localSocketPath: "/tmp/\(alias)-local.sock",
            deployed: true,
            lastSetupVersion: lastSetupVersion,
            trustStatus: "trusted",
            hookVersion: hookVersion,
            hookUpdateAvailable: true
        )
    }

    private func row(
        id: String,
        banner: RemoteHookUpdateBanner?
    ) -> RemoteHookUpdateBannerRowFixture {
        RemoteHookUpdateBannerRowFixture(
            id: id,
            isPresent: banner != nil,
            hostId: banner?.hostId,
            hostAlias: banner?.hostAlias,
            currentHookVersion: banner?.currentHookVersion,
            supportedHookVersion: banner?.supportedHookVersion,
            repairAction: banner?.repairAction.rawValue,
            redeployCommandPreview: banner?.redeployCommandPreview
        )
    }

    private struct RemoteHookUpdateBannerMatrixFixture: Codable, Equatable {
        let rows: [RemoteHookUpdateBannerRowFixture]
    }

    private struct RemoteHookUpdateBannerRowFixture: Codable, Equatable {
        let id: String
        let isPresent: Bool
        let hostId: String?
        let hostAlias: String?
        let currentHookVersion: String?
        let supportedHookVersion: String?
        let repairAction: String?
        let redeployCommandPreview: String?
    }
}
