import Foundation

public struct SoundPackStoreSnapshot: Codable, Equatable, Sendable {
    public let manifests: [SoundPackManifest]
    public let selectedPackId: String?

    public init(
        manifests: [SoundPackManifest] = [],
        selectedPackId: String? = nil
    ) {
        self.manifests = manifests
        self.selectedPackId = selectedPackId
    }
}

public enum SoundPackStoreValidationIssueKind: String, Codable, Equatable, Sendable {
    case duplicateManifestId
    case missingSelectedManifest
    case invalidManifest
}

public struct SoundPackStoreValidationIssue: Codable, Equatable, Sendable {
    public let kind: SoundPackStoreValidationIssueKind
    public let manifestId: String

    public init(kind: SoundPackStoreValidationIssueKind, manifestId: String) {
        self.kind = kind
        self.manifestId = manifestId
    }
}

public struct SoundPackStoreValidationReport: Codable, Equatable, Sendable {
    public let issues: [SoundPackStoreValidationIssue]

    public var isValid: Bool {
        issues.isEmpty
    }

    public init(issues: [SoundPackStoreValidationIssue]) {
        self.issues = issues
    }
}

public struct SoundPackStore: Sendable {
    public let snapshot: SoundPackStoreSnapshot

    public var selectedManifest: SoundPackManifest? {
        guard let selectedPackId = snapshot.selectedPackId else {
            return nil
        }
        return manifest(id: selectedPackId)
    }

    public var validationReport: SoundPackStoreValidationReport {
        var issues: [SoundPackStoreValidationIssue] = []
        var seenIds = Set<String>()
        var duplicateIds = Set<String>()

        for manifest in snapshot.manifests {
            if seenIds.contains(manifest.id), !duplicateIds.contains(manifest.id) {
                issues.append(SoundPackStoreValidationIssue(kind: .duplicateManifestId, manifestId: manifest.id))
                duplicateIds.insert(manifest.id)
            }
            seenIds.insert(manifest.id)
        }

        if let selectedPackId = snapshot.selectedPackId, manifest(id: selectedPackId) == nil {
            issues.append(SoundPackStoreValidationIssue(kind: .missingSelectedManifest, manifestId: selectedPackId))
        }

        for manifest in snapshot.manifests where !manifest.validationReport.isValid {
            issues.append(SoundPackStoreValidationIssue(kind: .invalidManifest, manifestId: manifest.id))
        }

        return SoundPackStoreValidationReport(issues: issues)
    }

    public init(snapshot: SoundPackStoreSnapshot = SoundPackStoreSnapshot()) {
        self.snapshot = snapshot
    }

    public func manifest(id: String) -> SoundPackManifest? {
        snapshot.manifests.first { $0.id == id }
    }

    public func sounds(for category: NotificationSoundCategory) -> [SoundPackSoundEntry] {
        selectedManifest?.sounds(for: category) ?? []
    }
}
