import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitSSHDeployResultController {
    public private(set) var lastResult: SSHDeployResult?

    private let publishResult: @MainActor (SSHDeployResult) -> Void

    public init(
        lastResult: SSHDeployResult? = nil,
        publishResult: @escaping @MainActor (SSHDeployResult) -> Void = { _ in }
    ) {
        self.lastResult = lastResult
        self.publishResult = publishResult
    }

    public var isDeployed: Bool {
        lastResult?.deployed == true
    }

    @discardableResult
    public func record(_ result: SSHDeployResult) -> SSHDeployResult {
        lastResult = result
        publishResult(result)
        return result
    }

    public func clear() {
        lastResult = nil
    }
}
