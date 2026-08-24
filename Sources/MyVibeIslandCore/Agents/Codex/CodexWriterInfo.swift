import Foundation
import MyVibeIslandShared

public enum CodexWriterOutcome: String, Codable, Equatable, Sendable {
    case matched
    case admissionDenied
    case notFound
    case unknown
}

/// Resolves the process that currently owns a Codex rollout. The command
/// sequence mirrors V3's watcher worker: `lsof -F p <rollout>` followed by
/// `ps -p <pid> -o tty=` for each candidate writer PID.
public struct CodexWriterInfoResolver: @unchecked Sendable {
    public static let lsofExecutable = "/usr/sbin/lsof"
    public static let psExecutable = "/bin/ps"
    private static let queryTimeout: TimeInterval = 5
    private static let maximumOutputBytes = 1_048_576

    private let runner: LocalProcessSnapshotRunning
    private let terminalBundleId: @Sendable (Int) -> String?
    private let deniedAncestorBundleId: @Sendable (Int) -> String?

    public init(
        runner: LocalProcessSnapshotRunning = SystemLocalProcessSnapshotRunner(),
        terminalBundleId: @escaping @Sendable (Int) -> String? = { pid in
            AncestorAppBundleDetector.firstAncestorBundleId(fromPid: Int32(pid), maxDepth: 5)
        },
        deniedAncestorBundleId: @escaping @Sendable (Int) -> String? = { pid in
            let rules = SessionAdmissionConfig.load(from: SessionAdmissionConfig.configURL())
            return AncestorAppBundleDetector.firstMatchingAncestorBundleId(
                fromPid: Int32(pid),
                matching: AppBundleAdmissionPolicy.deniedAncestorBundleIds(
                    userRules: rules.deniedAncestorBundles
                ),
                maxDepth: 5
            )
        }
    ) {
        self.runner = runner
        self.terminalBundleId = terminalBundleId
        self.deniedAncestorBundleId = deniedAncestorBundleId
    }

    public func resolve(rolloutPath: String) -> CodexWriterInfo {
        let pids: [Int]
        do {
            pids = try writerPIDs(for: rolloutPath)
        } catch {
            return CodexWriterInfo(outcome: .notFound)
        }

        for pid in pids {
            guard let tty = try? writerTTY(for: pid) else { continue }
            if let deniedBundleId = deniedAncestorBundleId(pid) {
                return CodexWriterInfo(
                    tty: tty,
                    pid: pid,
                    admissionDeniedAncestorBundleId: deniedBundleId,
                    outcome: .admissionDenied
                )
            }
            return CodexWriterInfo(
                tty: tty,
                pid: pid,
                terminalBundleId: terminalBundleId(pid),
                outcome: .matched
            )
        }

        return CodexWriterInfo(outcome: pids.isEmpty ? .notFound : .unknown)
    }

    private func writerPIDs(for rolloutPath: String) throws -> [Int] {
        let output = try runner.run(
            executable: Self.lsofExecutable,
            arguments: ["-F", "p", rolloutPath],
            timeout: Self.queryTimeout,
            maximumOutputBytes: Self.maximumOutputBytes
        )
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard line.first == "p" else { return nil }
                return Int(line.dropFirst())
            }
    }

    private func writerTTY(for pid: Int) throws -> String? {
        let output = try runner.run(
            executable: Self.psExecutable,
            arguments: ["-p", String(pid), "-o", "tty="],
            timeout: Self.queryTimeout,
            maximumOutputBytes: Self.maximumOutputBytes
        )
        guard let tty = output
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !tty.isEmpty,
            tty != "?",
            tty != "??" else {
            return nil
        }
        return tty.hasPrefix("/") ? tty : "/dev/\(tty)"
    }
}

public struct CodexWriterInfo: Codable, Equatable, Sendable {
    public let tty: String?
    public let pid: Int?
    public let terminalBundleId: String?
    public let admissionDeniedAncestorBundleId: String?
    public let outcome: CodexWriterOutcome

    public init(
        tty: String? = nil,
        pid: Int? = nil,
        terminalBundleId: String? = nil,
        admissionDeniedAncestorBundleId: String? = nil,
        outcome: CodexWriterOutcome = .unknown
    ) {
        self.tty = tty
        self.pid = pid
        self.terminalBundleId = terminalBundleId
        self.admissionDeniedAncestorBundleId = admissionDeniedAncestorBundleId
        self.outcome = outcome
    }

    public var isAdmissionDenied: Bool {
        outcome == .admissionDenied || admissionDeniedAncestorBundleId?.isEmpty == false
    }

    public var terminalIdentityKey: String? {
        let parts: [String?] = [
            pid.map { "pid=\($0)" },
            keyedPart(name: "terminalBundleId", value: terminalBundleId),
            keyedPart(name: "tty", value: tty)
        ]

        let compactParts = parts.compactMap { $0 }
        guard !compactParts.isEmpty else {
            return nil
        }

        return compactParts.joined(separator: "|")
    }

    private func keyedPart(name: String, value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return "\(name)=\(value)"
    }
}
