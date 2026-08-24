struct OriginalSessionCardHorizontalIdentityTagPlan: Sendable {
    enum Tag: Equatable, Sendable {
        case remote(String)
        case terminal(String)
    }

    let tags: [Tag]

    static func resolve(
        remoteGate: Bool,
        remoteProducer: String?,
        terminalLabel: String,
        terminalGate: Bool,
        baselineLabel: String
    ) -> Self {
        var tags: [Tag] = []

        if remoteGate {
            tags.append(.remote("📡 " + (remoteProducer ?? "Remote")))
        }
        if terminalGate, terminalLabel != baselineLabel {
            tags.append(.terminal(terminalLabel))
        }

        return Self(tags: tags)
    }
}
