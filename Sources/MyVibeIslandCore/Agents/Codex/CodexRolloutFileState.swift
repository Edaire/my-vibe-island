import Foundation

public struct CodexRolloutFileState: Equatable, Sendable {
    public static let maximumRemainderSize = 262_144

    public var offset: UInt64
    public var size: UInt64
    public var inode: UInt64?
    public var consumedDigest: UInt64
    public var modificationDate: Date?
    public var remainder: Data
    public var discardingOversizedLine: Bool
    public var isTailBootstrapped: Bool

    public init(
        offset: UInt64 = 0,
        size: UInt64 = 0,
        inode: UInt64? = nil,
        consumedDigest: UInt64 = 14_695_981_039_346_656_037,
        modificationDate: Date? = nil,
        remainder: Data = Data(),
        discardingOversizedLine: Bool = false,
        isTailBootstrapped: Bool = false
    ) {
        self.offset = offset
        self.size = size
        self.inode = inode
        self.consumedDigest = consumedDigest
        self.modificationDate = modificationDate
        self.remainder = remainder
        self.discardingOversizedLine = discardingOversizedLine
        self.isTailBootstrapped = isTailBootstrapped
    }
}
