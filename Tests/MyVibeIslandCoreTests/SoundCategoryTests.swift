import XCTest
@testable import MyVibeIslandCore

final class SoundCategoryTests: XCTestCase {
    func testCasesAndRawValuesMatchIDAOrder() {
        XCTAssertEqual(SoundCategory.allCases, [
            .sessionStart, .taskAcknowledge, .taskComplete, .taskError, .inputRequired,
            .resourceLimit, .userSpam, .idleReminder, .usageWarning, .usageReset,
        ])
        XCTAssertEqual(SoundCategory.allCases.map(\.rawValue), [
            "session.start", "task.acknowledge", "task.complete", "task.error", "input.required",
            "resource.limit", "user.spam", "vibe.idle.reminder", "vibe.usage.warning", "vibe.usage.reset",
        ])
    }

    func testNotificationCategoriesMapToRecoveredSoundCategories() {
        XCTAssertEqual(SoundCategory(notificationCategory: .permission), .inputRequired)
        XCTAssertEqual(SoundCategory(notificationCategory: .question), .inputRequired)
        XCTAssertEqual(SoundCategory(notificationCategory: .completion), .taskComplete)
        XCTAssertEqual(SoundCategory(notificationCategory: .failure), .taskError)
        XCTAssertEqual(SoundCategory(notificationCategory: .warning), .resourceLimit)
        XCTAssertEqual(SoundCategory(notificationCategory: .usage), .usageWarning)
        XCTAssertEqual(SoundCategory(notificationCategory: .remote), .sessionStart)
    }
}
