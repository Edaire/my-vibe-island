struct OriginalSessionCardHorizontalStatusMarkPlan: Equatable, Sendable {
    enum Color: Equatable, Sendable {
        case white(opacity: Double)
    }

    enum Alignment: Equatable, Sendable {
        case center
    }

    let foreground: Color
    let width: Double
    let height: Double
    let alignment: Alignment

    static let original = Self(
        foreground: .white(opacity: 0.20),
        width: 6,
        height: 6,
        alignment: .center
    )
}
