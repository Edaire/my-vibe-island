import Foundation

public enum AncestorAppBundleDetector {
    public static func appBundlePath(containing executablePath: String) -> String? {
        let parts = executablePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let index = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return parts[...index].joined(separator: "/")
    }

    public static func firstMatchingAncestorBundleId(
        fromPid pid: Int32,
        matching bundleIds: Set<String>,
        maxDepth: Int
    ) -> String? {
        guard maxDepth > 0, !bundleIds.isEmpty else { return nil }
        var current = pid
        for _ in 0..<maxDepth {
            guard let row = processRow(pid: current) else { return nil }
            if let bundleId = bundleIdentifier(forExecutablePath: row.command),
               bundleIds.contains(bundleId) {
                return bundleId
            }
            guard row.parentPid > 0, row.parentPid != current else { return nil }
            current = row.parentPid
        }
        return nil
    }

    public static func firstAncestorBundleId(fromPid pid: Int32, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }
        var current = pid
        for _ in 0..<maxDepth {
            guard let row = processRow(pid: current) else { return nil }
            if let bundleId = bundleIdentifier(forExecutablePath: row.command) {
                return bundleId
            }
            guard row.parentPid > 0, row.parentPid != current else { return nil }
            current = row.parentPid
        }
        return nil
    }

    private static func bundleIdentifier(forExecutablePath path: String) -> String? {
        guard let appPath = appBundlePath(containing: path),
              let bundle = Bundle(path: appPath) else {
            return nil
        }
        return bundle.bundleIdentifier
    }

    private static func processRow(pid: Int32) -> (parentPid: Int32, command: String)? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "ppid=", "-o", "comm=", "-p", String(pid)]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let firstSpace = output.firstIndex(where: \.isWhitespace),
              let parentPid = Int32(output[..<firstSpace].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        let command = output[firstSpace...].trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : (parentPid, command)
    }
}
