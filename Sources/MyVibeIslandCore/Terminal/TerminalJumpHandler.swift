public protocol TerminalJumpHandler: Sendable {
    var handlerId: String { get }

    func canHandle(_ input: JumpInput) -> Bool
    func execute(_ input: JumpInput) -> JumpResult
}
