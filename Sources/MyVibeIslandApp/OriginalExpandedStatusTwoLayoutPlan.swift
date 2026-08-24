import Foundation

/// Layout constants recovered from the original root's status-2 branch.
/// The completion card is a sibling of the base expanded body, so its insets
/// are intentionally independent from the base wrapper's insets.
enum OriginalExpandedStatusTwoLayoutPlan {
    static let baseHorizontalInset = 13.0
    static let baseVerticalInset = 4.0
    static let completionHorizontalInset = 8.0
    static let completionTopInset = 4.0
}
