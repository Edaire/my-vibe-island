import AppKit
import Foundation

@MainActor
public final class MyVibeIslandAppKitDiagnosticExportPresenter {
    private let controller: MyVibeIslandAppKitDiagnosticExportController
    private let selectDestination: @MainActor () -> URL?

    public init(
        controller: MyVibeIslandAppKitDiagnosticExportController,
        selectDestination: @escaping @MainActor () -> URL? = {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "Vibe-Island-Diagnostics.zip"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            return panel.runModal() == .OK ? panel.url : nil
        }
    ) {
        self.controller = controller
        self.selectDestination = selectDestination
    }

    @discardableResult
    public func export() throws -> URL? {
        guard let destination = selectDestination() else { return nil }
        return try controller.exportDiagnostics(to: destination)
    }
}
