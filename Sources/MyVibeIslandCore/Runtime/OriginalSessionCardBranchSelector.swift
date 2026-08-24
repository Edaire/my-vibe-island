import Foundation

public enum OriginalSessionCardBranchSelector {
    public static func resolve(
        derivedCollectionCount: Int,
        manuallyExpanded: Bool?,
        statusWarning: Bool?,
        isFirst: Bool?,
        dateAtOffset24: Date?,
        now: Date,
        isCompletionPreview: Bool
    ) -> OriginalSessionCardShellPlan.Axis {
        // V3: sub_1006CC64C writes false for completion previews. Normal rows
        // receive sub_10013495C's result in SessionCardView.isCollapsed.
        guard !isCompletionPreview,
              derivedCollectionCount >= 4,
              manuallyExpanded != true,
              statusWarning == true,
              isFirst == false,
              let dateAtOffset24,
              now.timeIntervalSince(dateAtOffset24) > 900
        else {
            return .vertical
        }
        return .horizontal
    }
}
