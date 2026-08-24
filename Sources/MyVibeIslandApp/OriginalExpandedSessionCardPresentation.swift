import Foundation
import MyVibeIslandCore

/// Single projection used by an expanded card and its optional completion body.
/// Rendering paths receive the same session-derived values rather than deriving
/// title, activity, and completion content independently.
struct OriginalExpandedSessionCardPresentation: Equatable {
    let id: String
    let header: OriginalExpandedSessionHeaderDescriptor
    let body: OriginalExpandedVerticalBodyDescriptor
    let jumpAvailable: Bool

    static func resolve(row: OriginalExpandedSessionRow, now: Date = Date()) -> Self {
        Self(
            id: row.id,
            header: OriginalExpandedSessionHeaderDescriptor.resolve(row: row, now: now),
            body: OriginalExpandedVerticalBodyDescriptor.resolve(row: row),
            jumpAvailable: row.preview.jumpAvailable
        )
    }

    var completionAssistantMessage: String? { body.assistantMessage }
    var hasUnreadCompletion: Bool { body.hasUnreadCompletion }
}
