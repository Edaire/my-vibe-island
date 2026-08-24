import Foundation

public enum DiagnosticBundle {
    public enum DiagnosticError: String, Codable, Equatable, Sendable {
        case cannotCreateArchive
        case sectionGenerationFailed
        case redactionFailed
        case permissionDenied
        case crashReportCollectionFailed
        case hangSampleReadFailed
    }
}
