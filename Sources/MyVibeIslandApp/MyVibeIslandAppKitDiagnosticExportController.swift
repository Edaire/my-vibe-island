import Foundation
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandAppKitDiagnosticExportController {
    public private(set) var lastPlan: DiagnosticExportWritePlan?

    private let builder: DiagnosticExportBuilder
    private let writer: DiagnosticExportWriter
    private let archiveWriter: MyVibeIslandDiagnosticArchiveWriter
    private let collectInputs: @MainActor () -> [DiagnosticExportSectionInput]
    private let publishPlan: @MainActor (DiagnosticExportWritePlan) -> Void

    public init(
        builder: DiagnosticExportBuilder = DiagnosticExportBuilder(),
        writer: DiagnosticExportWriter = DiagnosticExportWriter(),
        archiveWriter: MyVibeIslandDiagnosticArchiveWriter = MyVibeIslandDiagnosticArchiveWriter(),
        collectInputs: @escaping @MainActor () -> [DiagnosticExportSectionInput] = { [] },
        publishPlan: @escaping @MainActor (DiagnosticExportWritePlan) -> Void = { _ in }
    ) {
        self.builder = builder
        self.writer = writer
        self.archiveWriter = archiveWriter
        self.collectInputs = collectInputs
        self.publishPlan = publishPlan
    }

    public static func production(
        runtime: AppRuntime? = nil,
        defaults: UserDefaults = .standard,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        appVersion: @escaping @MainActor () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        },
        buildVersion: @escaping @MainActor () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        }
    ) -> MyVibeIslandAppKitDiagnosticExportController {
        let integrationController = MyVibeIslandAppKitIntegrationCoordinatorController.production(
            homeDirectory: homeDirectory
        )
        return MyVibeIslandAppKitDiagnosticExportController(
            collectInputs: {
                _ = integrationController.refresh(
                    at: ISO8601DateFormatter().string(from: Date())
                )
                return productionInputs(
                    runtime: runtime,
                    defaults: defaults,
                    homeDirectory: homeDirectory,
                    integrations: integrationController.state,
                    appVersion: appVersion(),
                    buildVersion: buildVersion()
                )
            }
        )
    }

    @discardableResult
    public func exportDiagnostics() -> DiagnosticExportWritePlan {
        let sections = builder.buildSections(from: collectInputs())
        let plan = writer.planWrite(sections: sections)
        lastPlan = plan
        publishPlan(plan)
        return plan
    }

    @discardableResult
    public func exportDiagnostics(to archiveURL: URL) throws -> URL {
        try archiveWriter.write(plan: exportDiagnostics(), to: archiveURL)
    }

    private static func productionInputs(
        runtime: AppRuntime?,
        defaults: UserDefaults,
        homeDirectory: URL,
        integrations: IntegrationCoordinatorState,
        appVersion: String,
        buildVersion: String
    ) -> [DiagnosticExportSectionInput] {
        let runtimeStatus = runtime?.status()
        let island = runtime?.islandRuntimeSnapshot() ?? IslandRuntimeSnapshot()
        let settings = SettingsStore(
            fileURL: SettingsStore.defaultFileURL(homeDirectory: homeDirectory)
        ).loadSnapshot()
        let sound = SoundPreferencesStore(defaults: defaults).loadManagerSettings()
        let installedCount = integrations.rows.filter { $0.installState == .installed }.count
        let repairCount = integrations.rows.filter { $0.installState == .needsRepair }.count
        let failedCount = integrations.rows.filter { $0.healthState == .failed }.count
        let forbidden = [
            "credential", "environmentValues", "prompt", "providerToken",
            "secret", "sourceCode", "token", "toolInput", "transcript",
        ]

        func input(
            _ name: String,
            producer: String,
            fields: [String: String]
        ) -> DiagnosticExportSectionInput {
            DiagnosticExportSectionInput(
                name: name,
                producer: producer,
                allowedFields: fields.keys.sorted(),
                forbiddenFields: forbidden,
                fields: fields
            )
        }

        return [
            input("system-info.txt", producer: "app", fields: [
                "appVersion": appVersion,
                "buildVersion": buildVersion,
                "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
                "processBitness": "\(MemoryLayout<Int>.size * 8)-bit",
            ]),
            input("config-snapshot.txt", producer: "settings", fields: [
                "schemaVersion": String(settings.schemaVersion),
                "soundEnabled": String(sound.isEnabled),
                "usageDisplayEnabled": String(settings.usage.isUsageDisplayEnabled),
            ]),
            input("hooks-dump.txt", producer: "integration-scanner", fields: [
                "failedCount": String(failedCount),
                "installedCount": String(installedCount),
                "needsRepairCount": String(repairCount),
                "sourceCount": String(integrations.rows.count),
            ]),
            input("environment-snapshot.txt", producer: "runtime", fields: [
                "bridgeRunning": String(runtimeStatus?.isBridgeRunning ?? false),
                "localWatchersRunning": String(runtime?.areLocalSessionWatchersRunning ?? false),
            ]),
            input("codex-rollout-inventory.txt", producer: "runtime", fields: [
                "codexSessionCount": String(
                    island.sessionPreviews.filter {
                        $0.sourceBadge.localizedCaseInsensitiveContains("codex")
                    }.count
                ),
            ]),
            input("sessions-snapshot.txt", producer: "runtime", fields: [
                "actionRequestCount": String(island.actionRequestPreviews.count),
                "sessionCount": String(island.sessionPreviews.count),
                "unreadCompletionCount": String(
                    island.sessionPreviews.filter(\.unreadCompletionMarker).count
                ),
            ]),
            input("logs/", producer: "local-logger", fields: [
                "lineCount": "0",
                "redaction": "metadata-only",
            ]),
            input("README-privacy.txt", producer: "privacy-policy", fields: [
                "excludedData": DiagnosticReportPrivacyNote.default.excludedData
                    .map(\.rawValue)
                    .joined(separator: ","),
                "redactionLevel": DiagnosticReportPrivacyNote.default.redactionLevel.rawValue,
            ]),
        ]
    }
}
