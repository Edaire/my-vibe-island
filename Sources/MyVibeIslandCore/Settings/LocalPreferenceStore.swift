import Foundation

public final class LocalPreferenceStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    public func double(forKey key: String, default defaultValue: Double) -> Double {
        defaults.object(forKey: key) as? Double ?? defaultValue
    }

    public func integer(forKey key: String, default defaultValue: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? defaultValue
    }

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func set(_ value: Data?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
