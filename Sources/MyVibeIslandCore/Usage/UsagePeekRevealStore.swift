import Foundation

public actor UsagePeekRevealStore {
    private var revealedKeys: Set<String>

    public init(revealedKeys: Set<String> = []) {
        self.revealedKeys = revealedKeys
    }

    public func unrevealedIntents(from intents: [UsagePeekIntent]) -> [UsagePeekIntent] {
        var unrevealed: [UsagePeekIntent] = []

        for intent in intents where !revealedKeys.contains(intent.dedupeKey) {
            revealedKeys.insert(intent.dedupeKey)
            unrevealed.append(intent)
        }

        return unrevealed
    }

    public func hasRevealed(_ key: String) -> Bool {
        revealedKeys.contains(key)
    }

    public func resetForSettingsChange() {
        clear()
    }

    public func clear() {
        revealedKeys.removeAll()
    }
}
