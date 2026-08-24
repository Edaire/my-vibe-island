import Foundation

/// The original bridge distinguishes a tmux pane from a pane that can actually
/// be brought to the foreground: Terminal.app can only focus an attached tmux
/// client. A detached tmux session is therefore not a jump target.
public struct TmuxClientAttachment: Equatable, Sendable {
    public let hasAttachedClient: Bool
    public let clientTTY: String?

    public init(hasAttachedClient: Bool, clientTTY: String? = nil) {
        self.hasAttachedClient = hasAttachedClient
        self.clientTTY = clientTTY
    }
}

public struct TmuxClientAttachmentProbe: Sendable {
    private let run: @Sendable (String, [String]) -> String?

    public init() {
        run = Self.runTmux
    }

    public init(run: @escaping @Sendable (String, [String]) -> String?) {
        self.run = run
    }

    public func probe(socketPath: String?, pane: String?) -> TmuxClientAttachment? {
        guard let socketPath = nonEmpty(socketPath), let pane = nonEmpty(pane) else {
            return nil
        }
        guard let targetSession = nonEmpty(run(socketPath, [
            "display-message", "-p", "-t", pane, "#{session_name}",
        ])) else {
            return nil
        }
        guard let clients = run(socketPath, ["list-clients", "-F", "#{client_tty} #{client_session}"]) else {
            return nil
        }

        let clientTTY = clients
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard fields.count == 2, fields[1] == targetSession else { return nil }
                return nonEmpty(String(fields[0]))
            }
            .first
        return TmuxClientAttachment(hasAttachedClient: clientTTY != nil, clientTTY: clientTTY)
    }

    private static func runTmux(socketPath: String, arguments: [String]) -> String? {
        let paths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        guard let executable = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-S", socketPath] + arguments
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
