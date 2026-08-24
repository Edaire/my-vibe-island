import MyVibeIslandCore

public struct MyVibeIslandAppKitDiagnosticExportEntryRowDescriptor: Equatable {
    public let sectionName: String
    public let path: String
    public let redactionLevel: DiagnosticRedactionLevel
    public let fieldCount: Int

    public init(
        sectionName: String,
        path: String,
        redactionLevel: DiagnosticRedactionLevel,
        fieldCount: Int
    ) {
        self.sectionName = sectionName
        self.path = path
        self.redactionLevel = redactionLevel
        self.fieldCount = max(fieldCount, 0)
    }
}

public struct MyVibeIslandAppKitDiagnosticExportFailureRowDescriptor: Equatable {
    public let sectionName: String
    public let error: DiagnosticBundle.DiagnosticError

    public init(sectionName: String, error: DiagnosticBundle.DiagnosticError) {
        self.sectionName = sectionName
        self.error = error
    }
}

public struct MyVibeIslandAppKitDiagnosticExportContentDescriptor: Equatable {
    public let status: DiagnosticExportWritePlanStatus
    public let entryCount: Int
    public let failureCount: Int
    public let canWriteArchive: Bool
    public let entryRows: [MyVibeIslandAppKitDiagnosticExportEntryRowDescriptor]
    public let failureRows: [MyVibeIslandAppKitDiagnosticExportFailureRowDescriptor]

    public init(
        status: DiagnosticExportWritePlanStatus,
        entryCount: Int,
        failureCount: Int,
        canWriteArchive: Bool,
        entryRows: [MyVibeIslandAppKitDiagnosticExportEntryRowDescriptor],
        failureRows: [MyVibeIslandAppKitDiagnosticExportFailureRowDescriptor]
    ) {
        self.status = status
        self.entryCount = max(entryCount, 0)
        self.failureCount = max(failureCount, 0)
        self.canWriteArchive = canWriteArchive
        self.entryRows = entryRows
        self.failureRows = failureRows
    }
}

public struct MyVibeIslandAppKitDiagnosticExportContentAdapter {
    public init() {}

    public func makeDescriptor(
        from plan: DiagnosticExportWritePlan
    ) -> MyVibeIslandAppKitDiagnosticExportContentDescriptor {
        MyVibeIslandAppKitDiagnosticExportContentDescriptor(
            status: plan.status,
            entryCount: plan.entries.count,
            failureCount: plan.failures.count,
            canWriteArchive: plan.status == .ready && plan.failures.isEmpty,
            entryRows: plan.entries.map { entry in
                MyVibeIslandAppKitDiagnosticExportEntryRowDescriptor(
                    sectionName: entry.sectionName,
                    path: entry.path,
                    redactionLevel: entry.redactionLevel,
                    fieldCount: entry.fields.count
                )
            },
            failureRows: plan.failures.map { failure in
                MyVibeIslandAppKitDiagnosticExportFailureRowDescriptor(
                    sectionName: failure.sectionName,
                    error: failure.error
                )
            }
        )
    }
}
