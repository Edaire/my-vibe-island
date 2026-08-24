import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHRemoteHostController {
    public private(set) var hosts: [SSHRemoteHost]
    public private(set) var lastPublishedHosts: [SSHRemoteHost]?

    private let publishHosts: @MainActor ([SSHRemoteHost]) -> Void

    public init(
        hosts: [SSHRemoteHost] = [],
        publishHosts: @escaping @MainActor ([SSHRemoteHost]) -> Void = { _ in }
    ) {
        self.hosts = hosts.sorted { $0.hostId < $1.hostId }
        self.publishHosts = publishHosts
    }

    @discardableResult
    public func upsert(_ host: SSHRemoteHost) -> [SSHRemoteHost] {
        var next = hosts.filter { $0.hostId != host.hostId }
        next.append(host)
        hosts = next.sorted { $0.hostId < $1.hostId }
        publishCurrentHosts()
        return hosts
    }

    @discardableResult
    public func remove(hostId: String) -> Bool {
        let next = hosts.filter { $0.hostId != hostId }
        guard next.count != hosts.count else {
            return false
        }

        hosts = next
        publishCurrentHosts()
        return true
    }

    private func publishCurrentHosts() {
        lastPublishedHosts = hosts
        publishHosts(hosts)
    }
}
