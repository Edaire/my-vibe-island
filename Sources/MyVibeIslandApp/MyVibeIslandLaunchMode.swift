public enum MyVibeIslandLaunchMode: String, Equatable, Sendable {
    case dryRun
    case appKit
}

public struct MyVibeIslandLaunchModeResolution: Equatable, Sendable {
    public let mode: MyVibeIslandLaunchMode
    public let remainingArguments: [String]

    public init(
        mode: MyVibeIslandLaunchMode,
        remainingArguments: [String]
    ) {
        self.mode = mode
        self.remainingArguments = remainingArguments
    }
}

public struct MyVibeIslandLaunchModeResolver: Sendable {
    public init() {}

    public func resolve(arguments: [String]) -> MyVibeIslandLaunchModeResolution {
        var remaining: [String] = []
        var mode = MyVibeIslandLaunchMode.appKit

        for argument in arguments {
            if argument == "--run-appkit" {
                mode = .appKit
            } else if argument == "--dry-run" {
                mode = .dryRun
            } else {
                remaining.append(argument)
            }
        }

        return MyVibeIslandLaunchModeResolution(mode: mode, remainingArguments: remaining)
    }
}
