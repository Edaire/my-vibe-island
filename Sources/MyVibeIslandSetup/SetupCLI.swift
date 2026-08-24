import Foundation

public struct SetupCLI {
    public init() {}

    public func run(arguments: [String]) throws -> String {
        guard let command = arguments.first else {
            return commandList()
        }

        switch command {
        case "status":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            let statuses = SetupIntegrationScanner().scan(homeDirectory: homeDirectory)
            return statusOutput(statuses: statuses)
        case "dryRun", "dry-run", "dryrun":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            let plans = plans(homeDirectory: homeDirectory, action: .dryRun)
            return planOutput(header: "My Vibe Island setup dry run: no user configuration changed", plans: plans)
        case "explain":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            let plans = plans(homeDirectory: homeDirectory, action: .explain)
            if let sourceId = explainSourceId(from: arguments) {
                let filtered = plans.filter { $0.sourceId == sourceId }
                if filtered.isEmpty {
                    return "My Vibe Island setup explanation: no user configuration changed\nUnknown setup source: \(sourceId)"
                }
                return planOutput(header: "My Vibe Island setup explanation: no user configuration changed", plans: filtered)
            }
            return planOutput(header: "My Vibe Island setup explanation: no user configuration changed", plans: plans)
        case "install":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            let sourceId = sourceId(from: arguments) ?? ""
            let result = try SetupInstaller().install(sourceId: sourceId, homeDirectory: homeDirectory)
            return installOutput(result: result)
        case "uninstall":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            return installOutput(result: try SetupInstaller().uninstall(sourceId: sourceId(from: arguments) ?? "", homeDirectory: homeDirectory), operation: command)
        case "repair":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            return installOutput(result: try SetupInstaller().repair(sourceId: sourceId(from: arguments) ?? "", homeDirectory: homeDirectory), operation: command)
        case "verify":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            let sourceId = sourceId(from: arguments) ?? ""
            let verified = try SetupInstaller().verify(sourceId: sourceId, homeDirectory: homeDirectory)
            guard verified else { throw SetupCLIError.verificationFailed(sourceId) }
            return "My Vibe Island setup verify: \(verified ? "verified" : "failed")\n- \(sourceId): \(verified ? "managed integration is valid" : "managed integration is not valid")"
        case "print-manifest", "printManifest":
            let homeDirectory = homeDirectory(from: arguments) ?? FileManager.default.homeDirectoryForCurrentUser
            let manifests = try SetupManifestStore(homeDirectory: homeDirectory).all()
            return "My Vibe Island setup print-manifest:\n" + (manifests.isEmpty ? "- none" : manifests.map { "- \($0.sourceId): \($0.configPath) (version \($0.lastInstalledVersion ?? "unknown"))" }.joined(separator: "\n"))
        default:
            return commandList()
        }
    }

    private func commandList() -> String {
        "My Vibe Island setup. Commands: status, dryRun, explain, install, uninstall, repair, verify, print-manifest"
    }

    private func homeDirectory(from arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--home"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    private func explainSourceId(from arguments: [String]) -> String? {
        sourceId(from: arguments)
    }

    private func sourceId(from arguments: [String]) -> String? {
        for index in arguments.indices.dropFirst() {
            if arguments[index] == "--home" {
                return nil
            }
            if index > arguments.startIndex, arguments[arguments.index(before: index)] == "--home" {
                continue
            }
            if !arguments[index].hasPrefix("--") {
                return arguments[index]
            }
        }
        return nil
    }

    private func installOutput(result: SetupInstallResult, operation: String = "install") -> String {
        let status = result.changed ? "changed" : "no change"
        if result.relativePath.isEmpty {
            return "My Vibe Island setup \(operation): \(status)\n\(result.message)"
        }
        return "My Vibe Island setup \(operation): \(status)\n- \(result.sourceId): \(result.message) (\(result.relativePath))"
    }

    private func modeledOnlyOutput(command: String, sourceId: String?) -> String {
        let sourceSuffix = sourceId.map { " for \($0)" } ?? ""
        return "My Vibe Island setup \(command): no user configuration changed\n\(command)\(sourceSuffix) is modeled only; live mutation is not wired."
    }

    private func plans(homeDirectory: URL, action: SetupAction) -> [SetupPlan] {
        let planner = SetupPlanner()
        return SetupIntegrationScanner().scan(homeDirectory: homeDirectory).map { status in
            planner.plan(for: status, action: action)
        }
    }

    private func statusOutput(statuses: [SetupIntegrationStatus]) -> String {
        var lines = ["My Vibe Island setup status: no user configuration changed"]
        lines.append(contentsOf: statuses.map { status in
            "- \(status.sourceId): \(summary(for: status)) (\(status.relativePath))"
        })
        return lines.joined(separator: "\n")
    }

    private func planOutput(header: String, plans: [SetupPlan]) -> String {
        var lines = [header]
        for plan in plans {
            lines.append(contentsOf: plan.steps.map { step in
                "- \(plan.sourceId): \(step.blocked ? "blocked: " : "")\(step.message) (\(step.relativePath))"
            })
        }
        return lines.joined(separator: "\n")
    }

    private func summary(for status: SetupIntegrationStatus) -> String {
        if status.issues.contains(.managed) {
            return "managed"
        }
        if status.issues.contains(.managedStale) {
            return "stale"
        }
        if status.issues.contains(.configConflict) {
            return "conflict"
        }
        if status.issues.contains(.hooksDetected) {
            return "hooks detected"
        }
        if status.issues.contains(.pluginPresent) {
            return "plugin present"
        }
        if status.issues.contains(.configMalformed) {
            return "malformed"
        }
        if status.issues.contains(.configUnreadable) {
            return "unreadable"
        }
        if status.issues.contains(.pluginUnmanaged) {
            return "unmanaged"
        }
        if status.issues.contains(.pluginMissing) || status.issues.contains(.configMissing) {
            return "missing"
        }
        return "present"
    }
}
