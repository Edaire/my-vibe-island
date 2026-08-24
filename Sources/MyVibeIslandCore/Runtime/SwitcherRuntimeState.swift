public enum SwitcherNavigationDirection: Equatable, Sendable {
    case up
    case down
}

public struct SwitcherRuntimeState: Equatable, Sendable {
    public private(set) var sessionIDs: [String] = []
    public private(set) var highlightedIndex: Int?
    public private(set) var isOpen = false

    public var highlightedID: String? {
        guard let highlightedIndex, sessionIDs.indices.contains(highlightedIndex) else {
            return nil
        }
        return sessionIDs[highlightedIndex]
    }

    public init() {}

    public mutating func open(sessionIDs: [String], highlightedID: String?) {
        self.sessionIDs = sessionIDs
        guard !self.sessionIDs.isEmpty else {
            highlightedIndex = nil
            isOpen = false
            return
        }

        highlightedIndex = highlightedID.flatMap { sessionIDs.firstIndex(of: $0) } ?? 0
        isOpen = true
    }

    @discardableResult
    public mutating func navigate(
        _ direction: SwitcherNavigationDirection,
        reversed: Bool = false
    ) -> String? {
        guard isOpen,
              !sessionIDs.isEmpty,
              let highlightedIndex
        else {
            return nil
        }

        let step = direction == .down ? 1 : -1
        let adjustedStep = reversed ? -step : step
        let nextIndex = (highlightedIndex + adjustedStep + sessionIDs.count) % sessionIDs.count
        self.highlightedIndex = nextIndex
        return sessionIDs[nextIndex]
    }

    @discardableResult
    public mutating func selectHighlighted() -> String? {
        guard isOpen, let highlightedID else { return nil }
        collapse()
        return highlightedID
    }

    public mutating func collapseForModifierRelease() {
        collapse()
    }

    public mutating func collapseForOutsideInteraction() {
        collapse()
    }

    public mutating func collapse() {
        isOpen = false
        highlightedIndex = nil
    }
}
