import MyVibeIslandCore
import SwiftUI

public struct OriginalPeekSupplementalView: View {
    public let plan: OriginalPeekSupplementalContentPlan

    public init(state: OriginalPeekDisplayState) {
        self.plan = OriginalPeekSupplementalContentPlan.resolve(state)
    }

    public var body: some View {
        switch plan {
        case .row(let notification):
            OriginalPeekNotificationRowView(notification: notification)
                .padding(.horizontal, 4)
                .padding(.bottom, 5)
        case .empty:
            EmptyView()
        }
    }
}
