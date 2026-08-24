import Foundation

public struct ProcessTTYInfo: Equatable, Sendable {
    public let tty: String?
    public let parentProcessID: Int?

    public init(tty: String?, parentProcessID: Int?) {
        self.tty = tty
        self.parentProcessID = parentProcessID
    }
}

public protocol ProcessTTYResolving: Sendable {
    func tty(for processIdentifier: Int) -> String?
}

public struct ProcessTTYResolver: ProcessTTYResolving {
    private let processInfo: @Sendable (Int) -> ProcessTTYInfo?
    private let maximumAncestorDepth: Int

    public init(
        maximumAncestorDepth: Int = 12,
        processInfo: @escaping @Sendable (Int) -> ProcessTTYInfo? = Self.systemProcessInfo
    ) {
        self.maximumAncestorDepth = max(1, maximumAncestorDepth)
        self.processInfo = processInfo
    }

    public func tty(for processIdentifier: Int) -> String? {
        var processIdentifier = processIdentifier
        var visited: Set<Int> = []
        for _ in 0..<maximumAncestorDepth {
            guard processIdentifier > 1,
                  visited.insert(processIdentifier).inserted,
                  let info = processInfo(processIdentifier) else {
                return nil
            }
            if let tty = normalizedTTY(info.tty) {
                return tty
            }
            guard let parentProcessID = info.parentProcessID,
                  parentProcessID != processIdentifier else {
                return nil
            }
            processIdentifier = parentProcessID
        }
        return nil
    }

    private func normalizedTTY(_ tty: String?) -> String? {
        guard let tty = tty?.trimmingCharacters(in: .whitespacesAndNewlines),
              !tty.isEmpty,
              tty != "?", tty != "??" else {
            return nil
        }
        return tty.hasPrefix("/") ? tty : "/dev/\(tty)"
    }

    public static func systemProcessInfo(processIdentifier: Int) -> ProcessTTYInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "tty=,ppid=", "-p", String(processIdentifier)]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let text = String(
                decoding: output.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
            let values = text.split(whereSeparator: { $0.isWhitespace })
            guard values.count >= 2, let parentProcessID = Int(values[1]) else { return nil }
            return ProcessTTYInfo(tty: String(values[0]), parentProcessID: parentProcessID)
        } catch {
            return nil
        }
    }
}
