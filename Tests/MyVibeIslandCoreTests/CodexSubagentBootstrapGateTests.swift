import Foundation
import XCTest
@testable import MyVibeIslandCore

final class CodexSubagentBootstrapGateTests: XCTestCase {
    func testChildSessionMetadataSkipsInheritedHistory() {
        let metadata = #"{"type":"session_meta","payload":{"id":"child-thread","thread_source":"subagent","source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent-thread"}}}}}"#

        XCTAssertEqual(
            CodexSubagentBootstrapGate.resolve(initialData: Data(metadata.utf8)),
            .skipInheritedHistory
        )
    }

    func testRootSessionMetadataKeepsNormalBootstrap() {
        let metadata = #"{"type":"session_meta","payload":{"id":"root-thread","thread_source":"user","source":"cli"}}"#

        XCTAssertEqual(
            CodexSubagentBootstrapGate.resolve(initialData: Data(metadata.utf8)),
            .consumeInitialHistory
        )
    }
}
