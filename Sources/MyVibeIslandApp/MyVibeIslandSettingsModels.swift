import Foundation
import MyVibeIslandCore
import Observation

@MainActor
@Observable
final class MyVibeIslandSettingsModel {
    private let preferences: LocalPreferenceStore
    private let settingsStore: SettingsStore
    private let integrationController: MyVibeIslandAppKitIntegrationCoordinatorController

    private(set) var integrationSnapshot = IntegrationSettingsSnapshot(rows: [])

    var idleTimeoutHours: Double {
        didSet { preferences.set(idleTimeoutHours, forKey: "idleFallbackTimeoutHours") }
    }
    var autoConfigureNewlyDetectedCLIs: Bool {
        didSet { preferences.set(autoConfigureNewlyDetectedCLIs, forKey: "autoConfigureNewlyDetectedCLIs") }
    }
    var disableClaudeNativeTitle: Bool {
        didSet { preferences.set(disableClaudeNativeTitle, forKey: "disableClaudeNativeTitle") }
    }
    var usageValueMode: UsageValueMode {
        didSet { persistUsage() }
    }
    var usageThresholdPercent: Double {
        didSet { persistUsage() }
    }
    var usageThresholdAlert: Bool {
        didSet { persistUsage() }
    }
    var showUsage: Bool {
        didSet {
            preferences.set(showUsage, forKey: "showUsage")
            persistUsage()
        }
    }
    var cursorApproval: String {
        didSet { preferences.set(cursorApproval, forKey: "cursorApproval") }
    }
    var codexApprovalMode: String {
        didSet { preferences.set(codexApprovalMode, forKey: "codexApprovalMode") }
    }
    var kiroPermissionHintDelaySeconds: Int {
        didSet { preferences.set(kiroPermissionHintDelaySeconds, forKey: "kiroPermissionHintDelaySeconds") }
    }
    var receiveBetaUpdates: Bool {
        didSet { preferences.set(receiveBetaUpdates, forKey: "receiveBetaUpdates") }
    }
    var autoModeInsteadOfBypass: Bool {
        didSet { preferences.set(autoModeInsteadOfBypass, forKey: "autoModeInsteadOfBypass") }
    }
    var deferClaudeApprovalsToNative: Bool {
        didSet { preferences.set(deferClaudeApprovalsToNative, forKey: "deferClaudeApprovalsToNative") }
    }
    var memoryRestartEnabled: Bool {
        didSet { preferences.set(memoryRestartEnabled, forKey: "memoryRestartEnabled") }
    }

    init(
        preferences: LocalPreferenceStore = LocalPreferenceStore(),
        settingsStore: SettingsStore = SettingsStore(fileURL: SettingsStore.defaultFileURL()),
        integrationController: MyVibeIslandAppKitIntegrationCoordinatorController = .production()
    ) {
        self.preferences = preferences
        self.settingsStore = settingsStore
        self.integrationController = integrationController
        let snapshot = settingsStore.loadSnapshot()
        idleTimeoutHours = preferences.double(forKey: "idleFallbackTimeoutHours", default: 2)
        autoConfigureNewlyDetectedCLIs = preferences.bool(forKey: "autoConfigureNewlyDetectedCLIs", default: true)
        disableClaudeNativeTitle = preferences.bool(forKey: "disableClaudeNativeTitle", default: true)
        usageValueMode = snapshot.usage.valueMode
        usageThresholdPercent = Double(snapshot.usage.thresholdPercent)
        usageThresholdAlert = snapshot.usage.thresholdPeeksEnabled
        showUsage = preferences.bool(forKey: "showUsage", default: snapshot.usage.isUsageDisplayEnabled)
        cursorApproval = preferences.string(forKey: "cursorApproval") ?? "auto"
        codexApprovalMode = preferences.string(forKey: "codexApprovalMode") ?? "approve_here"
        kiroPermissionHintDelaySeconds = preferences.integer(forKey: "kiroPermissionHintDelaySeconds", default: 5)
        receiveBetaUpdates = preferences.bool(forKey: "receiveBetaUpdates", default: false)
        autoModeInsteadOfBypass = preferences.bool(forKey: "autoModeInsteadOfBypass", default: false)
        deferClaudeApprovalsToNative = preferences.bool(forKey: "deferClaudeApprovalsToNative", default: false)
        memoryRestartEnabled = preferences.bool(forKey: "memoryRestartEnabled", default: false)
    }

    @discardableResult
    func refreshIntegrations(
        at timestamp: String = ISO8601DateFormatter().string(from: Date())
    ) -> IntegrationSettingsSnapshot {
        _ = integrationController.refresh(at: timestamp)
        let snapshot = IntegrationSettingsModel().snapshot(from: integrationController.state)
        integrationSnapshot = snapshot
        return snapshot
    }

    @discardableResult
    func installIntegration(
        sourceId: String,
        at timestamp: String = ISO8601DateFormatter().string(from: Date())
    ) -> IntegrationRepairResult? {
        runIntegrationOperation(at: timestamp) {
            integrationController.install(sourceId: sourceId)
        }
    }

    @discardableResult
    func repairIntegration(
        sourceId: String,
        at timestamp: String = ISO8601DateFormatter().string(from: Date())
    ) -> IntegrationRepairResult? {
        runIntegrationOperation(at: timestamp) {
            integrationController.repair(sourceId: sourceId)
        }
    }

    @discardableResult
    func uninstallIntegration(
        sourceId: String,
        at timestamp: String = ISO8601DateFormatter().string(from: Date())
    ) -> IntegrationRepairResult? {
        runIntegrationOperation(at: timestamp) {
            integrationController.uninstall(sourceId: sourceId)
        }
    }

    private func runIntegrationOperation(
        at timestamp: String,
        operation: () -> Void
    ) -> IntegrationRepairResult? {
        operation()
        let result = integrationController.lastRepairResult
        _ = refreshIntegrations(at: timestamp)
        return result
    }

    private func persistUsage() {
        settingsStore.updateSnapshot { snapshot in
            SettingsSnapshot(
                schemaVersion: snapshot.schemaVersion,
                behaviour: snapshot.behaviour,
                shortcuts: snapshot.shortcuts,
                usage: UsageSettingsSnapshot(
                    preferredProviderId: snapshot.usage.preferredProviderId,
                    displayStyle: showUsage ? .ringBadge : .hidden,
                    valueMode: usageValueMode,
                    thresholdPeeksEnabled: usageThresholdAlert,
                    thresholdPercent: Int(usageThresholdPercent.rounded()),
                    usageNotificationsEnabled: snapshot.usage.usageNotificationsEnabled,
                    usageSoundEnabled: snapshot.usage.usageSoundEnabled,
                    labsProviderIds: snapshot.usage.labsProviderIds
                ),
                labs: snapshot.labs
            )
        }
    }
}

@MainActor
enum MyVibeIslandSettingsRuntime {
    static var shared = MyVibeIslandSettingsModel()
}
