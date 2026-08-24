import MyVibeIslandCore

public enum MyVibeIslandAppKitRuntimeOwnerAction: Equatable {
    case start(AppRuntimeOwner)
    case startFailed(AppRuntimeOwner)
    case stop(AppRuntimeOwner)
}

public enum MyVibeIslandAppKitRuntimeOwnerAvailability: Equatable {
    case available
    case unavailable(String)
}

public enum MyVibeIslandAppKitRuntimeOwnerResult: Equatable {
    case started(AppRuntimeOwner)
    case failed(AppRuntimeOwner, String)
    case unavailable(AppRuntimeOwner, String)
    case stopped(AppRuntimeOwner)
}

@MainActor
public final class MyVibeIslandAppKitRuntimeOwnerController {
    public private(set) var runningOwners: [AppRuntimeOwner] = []
    public private(set) var failures: [AppRuntimeOwner: String] = [:]
    public private(set) var lastAction: MyVibeIslandAppKitRuntimeOwnerAction?

    private let startOwner: @MainActor (AppRuntimeOwner) throws -> Void
    private let stopOwner: @MainActor (AppRuntimeOwner) -> Void
    private let unavailableOwners: [AppRuntimeOwner: String]
    private var results: [AppRuntimeOwner: MyVibeIslandAppKitRuntimeOwnerResult] = [:]

    public init(
        startOwner: @escaping @MainActor (AppRuntimeOwner) throws -> Void = { _ in },
        stopOwner: @escaping @MainActor (AppRuntimeOwner) -> Void = { _ in },
        unavailableOwners: [AppRuntimeOwner: String] = [:]
    ) {
        self.startOwner = startOwner
        self.stopOwner = stopOwner
        self.unavailableOwners = unavailableOwners
    }

    public func availability(of owner: AppRuntimeOwner) -> MyVibeIslandAppKitRuntimeOwnerAvailability {
        unavailableOwners[owner].map(MyVibeIslandAppKitRuntimeOwnerAvailability.unavailable) ?? .available
    }

    public func start(_ owner: AppRuntimeOwner) {
        guard !runningOwners.contains(owner) else { return }
        if let reason = unavailableOwners[owner] {
            failures[owner] = reason
            lastAction = .startFailed(owner)
            results[owner] = .unavailable(owner, reason)
            return
        }
        do {
            try startOwner(owner)
            runningOwners.append(owner)
            failures.removeValue(forKey: owner)
            lastAction = .start(owner)
            results[owner] = .started(owner)
        } catch {
            let reason = String(describing: type(of: error))
            failures[owner] = reason
            lastAction = .startFailed(owner)
            results[owner] = .failed(owner, reason)
        }
    }

    public func stop(_ owner: AppRuntimeOwner) {
        guard runningOwners.contains(owner) || failures[owner] != nil else { return }
        stopOwner(owner)
        runningOwners.removeAll { $0 == owner }
        failures.removeValue(forKey: owner)
        lastAction = .stop(owner)
        results[owner] = .stopped(owner)
    }

    public func result(for owner: AppRuntimeOwner) -> MyVibeIslandAppKitRuntimeOwnerResult? {
        results[owner]
    }

    public func stopAll() {
        for owner in runningOwners.reversed() {
            stop(owner)
        }
    }
}
