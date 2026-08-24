import Foundation

struct CodexTUIConfig {
    let contents: String

    func installingTerminalTitle() -> String {
        var lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var tuiSection: Int?
        var inTUI = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                inTUI = Self.isTUIHeader(trimmed)
                if inTUI, tuiSection == nil { tuiSection = index }
                continue
            }
            if inTUI, let equals = trimmed.firstIndex(of: "="),
               trimmed[..<equals].trimmingCharacters(in: .whitespaces) == "terminal_title" {
                return contents
            }
        }

        if let tuiSection {
            lines.insert("terminal_title = []", at: tuiSection + 1)
            return lines.joined(separator: "\n")
        }

        let suffix = contents.isEmpty || contents.hasSuffix("\n") ? "" : "\n"
        return contents + suffix + "[tui]\nterminal_title = []\n"
    }

    private static func isTUIHeader(_ line: String) -> Bool {
        guard line.hasPrefix("[tui]") else { return false }
        let suffix = line.dropFirst("[tui]".count).trimmingCharacters(in: .whitespaces)
        return suffix.isEmpty || suffix.hasPrefix("#")
    }
}
