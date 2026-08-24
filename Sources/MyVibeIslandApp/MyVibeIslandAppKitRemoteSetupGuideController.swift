import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitRemoteSetupGuideController {
    public private(set) var lastSidecarSetup: DockerSidecarSetup?
    public private(set) var lastManualGuide: ManualRemoteInstallGuide?

    private let publishSidecarSetup: @MainActor (DockerSidecarSetup) -> Void
    private let publishManualGuide: @MainActor (ManualRemoteInstallGuide) -> Void

    public init(
        lastSidecarSetup: DockerSidecarSetup? = nil,
        lastManualGuide: ManualRemoteInstallGuide? = nil,
        publishSidecarSetup: @escaping @MainActor (DockerSidecarSetup) -> Void = { _ in },
        publishManualGuide: @escaping @MainActor (ManualRemoteInstallGuide) -> Void = { _ in }
    ) {
        self.lastSidecarSetup = lastSidecarSetup
        self.lastManualGuide = lastManualGuide
        self.publishSidecarSetup = publishSidecarSetup
        self.publishManualGuide = publishManualGuide
    }

    public var requiresUserRunCommand: Bool {
        lastSidecarSetup?.requiresUserRunCommand == true
    }

    public var instructionsAreCopyable: Bool {
        lastManualGuide?.instructionsAreCopyable == true
    }

    @discardableResult
    public func present(sidecarSetup: DockerSidecarSetup) -> DockerSidecarSetup {
        lastSidecarSetup = sidecarSetup
        publishSidecarSetup(sidecarSetup)
        return sidecarSetup
    }

    @discardableResult
    public func present(manualGuide: ManualRemoteInstallGuide) -> ManualRemoteInstallGuide {
        lastManualGuide = manualGuide
        publishManualGuide(manualGuide)
        return manualGuide
    }

    public func clear() {
        lastSidecarSetup = nil
        lastManualGuide = nil
    }
}
