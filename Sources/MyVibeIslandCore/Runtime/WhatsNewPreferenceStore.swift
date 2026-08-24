import Foundation

public final class WhatsNewPreferenceStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> WhatsNewStoreState {
        guard let data = defaults.data(forKey: Self.stateKey),
              let state = try? decoder.decode(WhatsNewStoreState.self, from: data)
        else {
            return WhatsNewStoreState()
        }
        return state
    }

    public func save(_ state: WhatsNewStoreState) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: Self.stateKey)
    }

    private static let stateKey = "whatsNew.state"
}
