import Foundation

struct OriginalExpandedSessionLayoutPlan: Equatable, Sendable {
    let statusWidth: Double
    let statusHeight: Double
    let columnSpacing: Double
    let contentSpacing: Double
    let controlFrame: Double
    let controlGlyph: Double
    let controlSpacing: Double
    let defaultContentFontSize: Double
    let defaultCompletionMaximumHeight: Double

    static let original = Self(
        statusWidth: 43,
        statusHeight: 20,
        columnSpacing: 8,
        contentSpacing: 4,
        controlFrame: 24,
        controlGlyph: 14,
        controlSpacing: 8,
        defaultContentFontSize: 11,
        defaultCompletionMaximumHeight: 90
    )
}
