import Foundation

/// Process-first Codex rollout discovery. A transcript path is returned only
/// when it is currently open by a live `codex` process.
public struct CodexLiveRolloutDiscovery: Sendable {
    private static let metadataProbeBytes = 64 * 1024
    private let runner: LocalProcessSnapshotRunning

    public init(
        runner: LocalProcessSnapshotRunning = SystemLocalProcessSnapshotRunner()
    ) {
        self.runner = runner
    }

    public func discover() -> [CodexDiscoveredRolloutFile] {
        guard let processOutput = try? runner.run(
            executable: "/bin/ps",
            arguments: ["-axo", "pid=,command="],
            timeout: 2,
            maximumOutputBytes: 4_194_304
        ) else {
            return []
        }
        let pids = processOutput.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let fields = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 2, let _ = Int(fields[0]) else { return nil }
            let command = String(fields[1]).lowercased()
            guard command.contains("codex"), !command.contains("vibe-island") else { return nil }
            return String(fields[0])
        }
        guard !pids.isEmpty,
              let output = try? runner.run(
            executable: "/usr/sbin/lsof",
            arguments: ["-n", "-F", "pn", "-p", pids.joined(separator: ",")],
            timeout: 2,
            maximumOutputBytes: 4_194_304
        ) else {
            return []
        }

        let paths = Set(output.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            guard line.first == "n" else { return nil }
            let path = String(line.dropFirst())
            guard path.contains("/.codex/sessions/"),
                  URL(fileURLWithPath: path).lastPathComponent.hasPrefix("rollout-"),
                  path.hasSuffix(".jsonl") else {
                return nil
            }
            return path
        })

        return paths.compactMap(file).sorted { lhs, rhs in
            (lhs.modificationDate ?? .distantPast) > (rhs.modificationDate ?? .distantPast)
        }
    }

    /// Returns top-level Codex threads currently backed by a process. Child
    /// rollouts remain watcher input for lifecycle enrichment, but are not
    /// top-level session cards.
    public func discoverTopLevelSessionIDs() -> Set<String> {
        Set(discover().compactMap { file in
            guard let handle = try? FileHandle(forReadingFrom: file.url) else { return nil }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: Self.metadataProbeBytes),
                  let firstLine = data.split(separator: UInt8(ascii: "\n"), maxSplits: 1).first
            else { return nil }
            let snapshot = CodexRolloutReducer.snapshot(
                for: [String(decoding: firstLine, as: UTF8.self)]
            )
            guard let sessionID = snapshot.sessionId,
                  snapshot.subagentParentThreadId == nil else {
                return nil
            }
            return CodexSessionIdentity.prefixed(sessionID)
        })
    }

    private func file(at path: String) -> CodexDiscoveredRolloutFile? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              (attributes[.type] as? FileAttributeType) == .typeRegular else {
            return nil
        }
        return CodexDiscoveredRolloutFile(
            url: URL(fileURLWithPath: path).standardizedFileURL,
            size: (attributes[.size] as? NSNumber)?.uint64Value ?? 0,
            inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }
}
