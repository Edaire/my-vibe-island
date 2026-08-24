import XCTest
@testable import MyVibeIslandCore

final class CodexApprovalRoutingPolicyTests: XCTestCase {
    func testApproveHereKeepsApprovalInIslandWhileOwningTerminalIsNotFrontmost() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.route(
                target: "approve_here",
                owningTerminalIsFrontmost: false,
                ownershipDeadlineExpired: false
            ),
            .retainInIsland
        )
    }

    func testApproveHereRetainsApprovalWhenOwningTerminalIsFrontmostUntilDeadline() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.route(
                target: "approve_here",
                owningTerminalIsFrontmost: true,
                ownershipDeadlineExpired: false
            ),
            .retainInIsland
        )
    }

    func testApproveHereHandsOffAtOwnershipDeadline() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.route(
                target: "approve_here",
                owningTerminalIsFrontmost: false,
                ownershipDeadlineExpired: true
            ),
            .handoffToTerminal
        )
    }

    func testNotchOverrideKeepsApprovalInIslandEvenWhenTerminalIsFrontmost() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.route(
                target: "notch",
                owningTerminalIsFrontmost: true,
                ownershipDeadlineExpired: true
            ),
            .retainInIsland
        )
    }

    func testNotchOverrideUsesLocalResolutionPresentation() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.presentation(target: "notch"),
            .localResolution
        )
    }

    func testApproveHereDefaultPresentationUsesLocalResolution() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.presentation(target: nil),
            .localResolution
        )
    }

    func testTerminalOverrideImmediatelyHandsOff() {
        XCTAssertEqual(
            CodexApprovalRoutingPolicy.route(
                target: "terminal",
                owningTerminalIsFrontmost: false,
                ownershipDeadlineExpired: false
            ),
            .handoffToTerminal
        )
    }
}
