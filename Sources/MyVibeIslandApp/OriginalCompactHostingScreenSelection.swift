public struct OriginalCompactHostingScreenCandidate: Equatable, Sendable {
    public let identifier: String
    public let input: OriginalNSScreenMetricsInput

    public init(identifier: String, input: OriginalNSScreenMetricsInput) {
        self.identifier = identifier
        self.input = input
    }
}

public enum OriginalCompactHostingScreenSelection {
    public static func resolve(
        candidates: [OriginalCompactHostingScreenCandidate],
        selectedIdentifier: String?,
        mainIdentifier: String?,
        fallback: OriginalNSScreenMetricsInput
    ) -> OriginalNSScreenMetricsInput {
        candidates.first { $0.identifier == selectedIdentifier }?.input
            ?? candidates.first { $0.identifier == mainIdentifier }?.input
            ?? candidates.first?.input
            ?? fallback
    }
}
