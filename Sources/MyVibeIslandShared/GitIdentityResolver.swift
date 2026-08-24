import Foundation

public struct ProjectGitInfo: Equatable, Sendable {
    public let repoName: String
    public let worktreeName: String?
    public let branch: String?

    public init(repoName: String, worktreeName: String? = nil, branch: String? = nil) {
        self.repoName = repoName
        self.worktreeName = worktreeName
        self.branch = branch
    }
}

public enum GitIdentityResolution: Equatable, Sendable {
    case resolved(ProjectGitInfo)
    case notGitRepo
    case unavailable

    public var payloadStatus: String {
        switch self {
        case .resolved:
            return "ok"
        case .notGitRepo:
            return "notGitRepo"
        case .unavailable:
            return "unavailable"
        }
    }

    public var projectGitInfo: ProjectGitInfo? {
        if case let .resolved(info) = self { return info }
        return nil
    }
}

public enum GitIdentityResolver {
    public static func resolveCached(cwd: String, ttlSeconds _: Double = 60) -> GitIdentityResolution {
        resolve(cwd: cwd)
    }

    private static func resolve(cwd: String) -> GitIdentityResolution {
        guard let topLevel = runGit(["rev-parse", "--show-toplevel"], cwd: cwd) else {
            return .notGitRepo
        }
        let repoName = URL(fileURLWithPath: topLevel).lastPathComponent
        let branch = runGit(["branch", "--show-current"], cwd: cwd)
        let commonDir = runGit(["rev-parse", "--git-common-dir"], cwd: cwd)
        let worktreeName = worktreeName(topLevel: topLevel, commonDir: commonDir)
        return .resolved(ProjectGitInfo(repoName: repoName, worktreeName: worktreeName, branch: branch))
    }

    private static func worktreeName(topLevel: String, commonDir: String?) -> String? {
        guard let commonDir, commonDir.contains("/worktrees/") else { return nil }
        return URL(fileURLWithPath: topLevel).lastPathComponent
    }

    private static func runGit(_ arguments: [String], cwd: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
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
        return output.isEmpty ? nil : output
    }
}
