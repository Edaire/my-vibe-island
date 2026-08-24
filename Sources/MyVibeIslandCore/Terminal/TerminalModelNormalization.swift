enum TerminalModelNormalization {
    static func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }
}
