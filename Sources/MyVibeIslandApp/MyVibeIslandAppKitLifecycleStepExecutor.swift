import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitLifecycleStepExecutor {
    public private(set) var executedSteps: [AppLifecycleStep] = []
    public private(set) var failures: [AppLifecycleStep: String] = [:]

    private let executeStep: @MainActor (AppLifecycleStep) throws -> Void

    public init(
        executeStep: @escaping @MainActor (AppLifecycleStep) throws -> Void = { _ in }
    ) {
        self.executeStep = executeStep
    }

    @discardableResult
    public func execute(_ step: AppLifecycleStep) -> Bool {
        guard !executedSteps.contains(step) else { return true }
        do {
            try executeStep(step)
            executedSteps.append(step)
            failures.removeValue(forKey: step)
            return true
        } catch {
            failures[step] = String(describing: type(of: error))
            return false
        }
    }
}
