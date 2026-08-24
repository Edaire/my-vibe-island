import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitShortcutRecorderButtonController {
    public private(set) var state: ShortcutRecorderState
    public private(set) var specs: [HotKeyRegistrationSpec]
    public private(set) var lastResult: ShortcutRecorderResult?

    private let model: ShortcutRecorderModel
    private let renderState: @MainActor (ShortcutRecorderState) -> Void
    private let saveSpec: @MainActor (HotKeyRegistrationSpec) -> Void

    public init(
        specs: [HotKeyRegistrationSpec],
        state: ShortcutRecorderState = ShortcutRecorderState(),
        model: ShortcutRecorderModel = ShortcutRecorderModel(),
        renderState: @escaping @MainActor (ShortcutRecorderState) -> Void = { _ in },
        saveSpec: @escaping @MainActor (HotKeyRegistrationSpec) -> Void = { _ in }
    ) {
        self.specs = specs
        self.state = state
        self.model = model
        self.renderState = renderState
        self.saveSpec = saveSpec
    }

    @discardableResult
    public func beginRecording(specId: String) -> ShortcutRecorderResult {
        let result = model.beginRecording(specId: specId, from: state)
        apply(result)
        return result
    }

    @discardableResult
    public func capture(_ keyCombo: MyVibeIslandCore.KeyCombo) -> ShortcutRecorderResult {
        guard
            let activeSpecId = state.activeSpecId,
            let targetSpec = specs.first(where: { $0.id == activeSpecId })
        else {
            let result = ShortcutRecorderResult(decision: .ignored, nextState: state)
            apply(result)
            return result
        }

        let result = model.capture(
            keyCombo,
            for: targetSpec,
            existingSpecs: specs,
            from: state
        )
        apply(result)
        return result
    }

    @discardableResult
    public func setEnabled(_ isEnabled: Bool, specId: String) -> HotKeyRegistrationSpec? {
        guard let index = specs.firstIndex(where: { $0.id == specId }) else {
            return nil
        }

        let updatedSpec = model.setEnabled(isEnabled, for: specs[index])
        specs[index] = updatedSpec
        saveSpec(updatedSpec)
        return updatedSpec
    }

    private func apply(_ result: ShortcutRecorderResult) {
        state = result.nextState
        lastResult = result

        if let updatedSpec = result.updatedSpec,
           let index = specs.firstIndex(where: { $0.id == updatedSpec.id }) {
            specs[index] = updatedSpec
            saveSpec(updatedSpec)
        }

        renderState(state)
    }
}
