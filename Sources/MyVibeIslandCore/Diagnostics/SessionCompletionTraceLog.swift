import Foundation
import MyVibeIslandShared

public enum SessionCompletionTraceLog {
    public static func defaultFileURL(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MyVibeIsland", isDirectory: true)
            .appendingPathComponent("session-completion.log", isDirectory: false)
    }

    public static func append(
        stage: String,
        sessionId: String?,
        metadata: [String: String] = [:],
        fileURL: URL = defaultFileURL(),
        now: Date = Date(),
        maximumFileBytes: Int = 1_048_576,
        maximumMetadataValueCharacters: Int = 512
    ) {
        let values = metadata
            .sorted { $0.key < $1.key }
            .map {
                "\(sanitize($0.key))=\(bounded(sanitize($0.value), maximum: maximumMetadataValueCharacters))"
            }
            .joined(separator: " ")
        let line = [
            timestamp(for: now),
            "stage=\(bounded(sanitize(stage), maximum: maximumMetadataValueCharacters))",
            "sessionId=\(bounded(sanitize(sessionId ?? "-"), maximum: maximumMetadataValueCharacters))",
            "pid=\(ProcessInfo.processInfo.processIdentifier)",
            values,
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            + "\n"

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let lineData = Data(line.utf8)
            let existingSize = (try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?
                .intValue ?? 0
            if maximumFileBytes > 0, existingSize + lineData.count > maximumFileBytes {
                let previousFileURL = fileURL.appendingPathExtension("1")
                if FileManager.default.fileExists(atPath: previousFileURL.path) {
                    try FileManager.default.removeItem(at: previousFileURL)
                }
                try FileManager.default.moveItem(at: fileURL, to: previousFileURL)
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: lineData)
            try handle.close()
        } catch {
            // Diagnostics must never affect hook or app behavior.
        }
    }

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func bounded(_ value: String, maximum: Int) -> String {
        guard maximum >= 0, value.count > maximum else { return value }
        return String(value.prefix(maximum)) + "..."
    }

    private static func timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
