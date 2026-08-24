import Foundation

public struct ManagedTOMLHookConfig {
    public static let kimiBeginPrefix = "# BEGIN MY_VIBE_ISLAND_MANAGED_KIMI_HOOKS v"
    public static let beginMarker = "\(kimiBeginPrefix)1"
    public static let endMarker = "# END MY_VIBE_ISLAND_MANAGED_KIMI_HOOKS"
    public static let rootRestorePrefix = "# MY_VIBE_ISLAND_RESTORE_KIMI_ROOT_HOOKS "

    private let contents: String

    public init(contents: String) throws {
        try Self.validateFence(in: Self.lines(contents))
        try Self.validateRootHooks(in: Self.lines(contents))
        _ = try Self.ownedStrayRanges(in: Self.lines(contents), excludingFence: true)
        self.contents = contents
    }

    public func install(sourceId: String, events: [String], helperCommand: String, version: Int) throws -> String {
        var lines = Self.lines(contents)
        lines = try Self.removingFence(from: lines)
        lines = try Self.removingOwnedStrayBlocks(from: lines)
        lines = try Self.commentingSimpleRootHooks(in: lines)
        let base = lines.joined(separator: "\n")
        let block = Self.render(sourceId: sourceId, events: events, helperCommand: helperCommand, version: version)
        return base.isEmpty ? block : base + "\n" + block
    }

    public func uninstall() throws -> String {
        var lines = Self.lines(contents)
        lines = try Self.removingFence(from: lines)
        lines = try Self.removingOwnedStrayBlocks(from: lines)
        lines = Self.restoringRootHooks(in: lines)
        return lines.joined(separator: "\n")
    }

    public func verify(sourceId: String, events: [String], helperCommand: String, version: Int) throws -> Bool {
        let lines = Self.lines(contents)
        guard let fence = Self.fenceRange(in: lines) else { return false }
        let expected = Self.lines(Self.render(sourceId: sourceId, events: events, helperCommand: helperCommand, version: version)).dropLast()
        let ownedStrays = try Self.ownedStrayRanges(in: lines, excludingFence: true)
        return Array(lines[fence]) == Array(expected) && ownedStrays.isEmpty
    }

    private static func render(sourceId: String, events: [String], helperCommand: String, version: Int) -> String {
        var lines = ["\(kimiBeginPrefix)\(version)"]
        for event in events {
            lines += [
                "[[hooks]]",
                "name = \"my-vibe-island\"",
                "source = \"\(sourceId)\"",
                "event = \"\(event)\"",
                "command = \"\(helperCommand) --source \(sourceId) --event \(event)\"",
                "timeout = 30",
                "managed_by = \"my-vibe-island\"",
                "version = \(version)",
                ""
            ]
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func validateFence(in lines: [String]) throws {
        let begins = lines.indices.filter { lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix(kimiBeginPrefix) }
        let ends = lines.indices.filter { lines[$0].trimmingCharacters(in: .whitespaces) == endMarker }
        guard begins.count == ends.count, begins.count <= 1 else { throw ManagedHookConfigError.malformed }
        guard let begin = begins.first, let end = ends.first else { return }
        guard begin < end else { throw ManagedHookConfigError.malformed }

        var index = begin + 1
        while index < end {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            guard trimmed == "[[hooks]]" else { throw ManagedHookConfigError.unmanagedConflict }
            let blockStart = index
            index += 1
            while index < end, lines[index].trimmingCharacters(in: .whitespaces) != "[[hooks]]" {
                index += 1
            }
            let block = Array(lines[blockStart..<index])
            let joined = block.joined(separator: "\n")
            let allowed = block.dropFirst().allSatisfy { line in
                let value = line.trimmingCharacters(in: .whitespaces)
                return value.isEmpty || value.hasPrefix("name =") || value.hasPrefix("source =") ||
                    value.hasPrefix("event =") || value.hasPrefix("command =") || value.hasPrefix("timeout =") ||
                    value.hasPrefix("managed_by =") || value.hasPrefix("version =")
            }
            guard allowed else { throw ManagedHookConfigError.unmanagedConflict }
            let hasMarker = joined.contains("managed_by = \"my-vibe-island\"")
            let hasSource = joined.contains("source = \"kimi\"")
            let hasCommand = joined.contains("--source kimi")
            guard hasMarker, hasSource, hasCommand else {
                if hasMarker || hasSource || hasCommand { throw ManagedHookConfigError.malformed }
                throw ManagedHookConfigError.unmanagedConflict
            }
        }
    }

    private static func validateRootHooks(in lines: [String]) throws {
        var inRoot = true
        var activeAssignments = 0
        var restoreMarkers = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(rootRestorePrefix) {
                restoreMarkers += 1
                continue
            }
            if trimmed.hasPrefix("[") {
                inRoot = false
                continue
            }
            guard inRoot, let value = rootHooksValue(in: trimmed) else { continue }
            activeAssignments += 1
            guard isSimpleSingleLineValue(value) else { throw ManagedHookConfigError.unmanagedConflict }
        }
        guard activeAssignments <= 1, restoreMarkers <= 1, activeAssignments + restoreMarkers <= 1 else {
            throw ManagedHookConfigError.unmanagedConflict
        }
    }

    private static func commentingSimpleRootHooks(in lines: [String]) throws -> [String] {
        try validateRootHooks(in: lines)
        var result = lines
        var inRoot = true
        for index in result.indices {
            let trimmed = result[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(rootRestorePrefix) { return result }
            if trimmed.hasPrefix("[") {
                inRoot = false
                continue
            }
            if inRoot, rootHooksValue(in: trimmed) != nil {
                result[index] = rootRestorePrefix + result[index]
                return result
            }
        }
        return result
    }

    private static func restoringRootHooks(in lines: [String]) -> [String] {
        lines.map { line in
            guard line.hasPrefix(rootRestorePrefix) else { return line }
            return String(line.dropFirst(rootRestorePrefix.count))
        }
    }

    private static func rootHooksValue(in trimmed: String) -> String? {
        guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { return nil }
        let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
        guard key == "hooks" else { return nil }
        return trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
    }

    private static func isSimpleSingleLineValue(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        if value.hasPrefix("[") { return value.hasSuffix("]") }
        if value.hasPrefix("{") { return value.hasSuffix("}") }
        if value.hasPrefix("\"\"\"") { return value.count >= 6 && value.hasSuffix("\"\"\"") }
        if value.hasPrefix("'''") { return value.count >= 6 && value.hasSuffix("'''") }
        return true
    }

    private static func removingFence(from lines: [String]) throws -> [String] {
        try validateFence(in: lines)
        guard let fence = fenceRange(in: lines) else { return lines }
        var result = lines
        let start = fence.lowerBound > 0 && lines[fence.lowerBound - 1].isEmpty ? fence.lowerBound - 1 : fence.lowerBound
        result.removeSubrange(start..<fence.upperBound)
        return result
    }

    private static func fenceRange(in lines: [String]) -> Range<Int>? {
        guard let begin = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(kimiBeginPrefix) }),
              let end = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == endMarker })
        else { return nil }
        return begin..<(end + 1)
    }

    private static func removingOwnedStrayBlocks(from lines: [String]) throws -> [String] {
        var result = lines
        for range in try ownedStrayRanges(in: result, excludingFence: false).reversed() {
            result.removeSubrange(range)
        }
        return result
    }

    private static func ownedStrayRanges(in lines: [String], excludingFence: Bool) throws -> [Range<Int>] {
        let fenceBegin = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(kimiBeginPrefix) })
        let fenceEnd = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == endMarker })
        var ranges = [Range<Int>]()
        var index = 0
        while index < lines.count {
            let inFence = excludingFence && fenceBegin.map { index >= $0 } == true && fenceEnd.map { index <= $0 } == true
            guard !inFence, lines[index].trimmingCharacters(in: .whitespaces) == "[[hooks]]" else {
                index += 1
                continue
            }
            var end = index + 1
            while end < lines.count, !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix("[") { end += 1 }
            let block = lines[index..<end].joined(separator: "\n")
            let marker = block.contains("managed_by = \"my-vibe-island\"")
            let source = block.contains("source = \"kimi\"")
            let command = block.contains("--source kimi")
            guard marker else {
                index = end
                continue
            }
            if block.contains("source = ") && !source { throw ManagedHookConfigError.unmanagedConflict }
            guard source || command else { throw ManagedHookConfigError.malformed }
            ranges.append(index..<end)
            index = end
        }
        return ranges
    }

    private static func lines(_ contents: String) -> [String] {
        contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
