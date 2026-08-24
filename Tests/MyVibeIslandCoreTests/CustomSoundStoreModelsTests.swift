import XCTest
@testable import MyVibeIslandCore

final class CustomSoundStoreModelsTests: XCTestCase {
    func testCustomSoundDiagnosticsAndValidationMatchFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            CustomSoundDiagnosticsFixture.self,
            from: try FixtureLoader.data("sound/custom-sound-diagnostics")
        )
        let externalFile = CustomSoundFile(
            id: "custom.external",
            displayName: "External Tone",
            storedFileName: "/Users/admin/private/external-tone.wav",
            sourceMode: .referencedInPlace,
            format: .wav,
            durationMilliseconds: 1_200,
            createdAtUnixSeconds: 1_782_950_500,
            playbackSettings: CustomSoundPlaybackSettings(isEnabled: false)
        )
        let invalidFile = CustomSoundFile(
            id: "",
            displayName: "",
            storedFileName: "",
            sourceMode: .copiedIntoLibrary,
            format: .unknown,
            durationMilliseconds: -1,
            createdAtUnixSeconds: 1_782_950_500,
            playbackSettings: CustomSoundPlaybackSettings()
        )
        let store = CustomSoundStore(snapshot: CustomSoundStoreSnapshot(
            files: [Self.permissionTone, Self.permissionTone, externalFile, invalidFile],
            assignments: [.permission: "custom.permission", .failure: "missing.custom"],
            lastImportError: "failed to import /Users/admin/private/permission.wav",
            hasLoaded: true,
            isStarted: true,
            libraryDirectory: "/Users/admin/Library/Application Support/MyVibeIsland/Sounds",
            manifest: CustomSoundLibraryManifest(
                schemaVersion: 1,
                soundIds: ["custom.permission", "missing.manifest"],
                lastUpdatedUnixSeconds: 1_782_950_400,
                migrationVersion: 1
            )
        ))

        let actual = CustomSoundDiagnosticsFixture(
            storeDiagnosticSummary: store.diagnosticSummary,
            validationReport: store.validationReport,
            externalFileDiagnosticSummary: externalFile.diagnosticSummary
        )
        let encodedActual = String(data: try JSONEncoder().encode(actual), encoding: .utf8) ?? ""

        XCTAssertEqual(actual, expected)
        XCTAssertFalse(encodedActual.contains("/Users/admin/private"))
        XCTAssertFalse(encodedActual.contains("external-tone.wav"))
        XCTAssertFalse(encodedActual.contains("permission.wav"))
        XCTAssertFalse(encodedActual.contains("External Tone"))
    }

    func testCustomSoundLibrarySnapshotRoundTripsLocalState() throws {
        let snapshot = CustomSoundStoreSnapshot(
            files: [Self.permissionTone],
            assignments: [.permission: "custom.permission"],
            lastImportError: "failed to import /Users/admin/private/permission.wav",
            hasLoaded: true,
            isStarted: true,
            libraryDirectory: "/Users/admin/Library/Application Support/MyVibeIsland/Sounds",
            manifest: CustomSoundLibraryManifest(
                schemaVersion: 1,
                soundIds: ["custom.permission"],
                lastUpdatedUnixSeconds: 1_782_950_400,
                migrationVersion: 1
            )
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(CustomSoundStoreSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.manifest.soundIds, ["custom.permission"])
        XCTAssertEqual(decoded.assignments[.permission], "custom.permission")
    }

    func testCustomSoundPlaybackSettingsNormalizeUnsafeValues() {
        let settings = CustomSoundPlaybackSettings(
            volume: 1.25,
            cooldownSeconds: -5,
            trimStartMilliseconds: -10,
            trimEndMilliseconds: 100,
            shouldNormalize: true,
            isEnabled: true
        )

        XCTAssertEqual(settings.volume, 1)
        XCTAssertEqual(settings.cooldownSeconds, 0)
        XCTAssertEqual(settings.trimStartMilliseconds, 0)
        XCTAssertEqual(settings.trimEndMilliseconds, 100)
    }

    func testCustomSoundStoreResolvesAssignmentsAndValidatesLibrary() {
        let invalidFile = CustomSoundFile(
            id: "",
            displayName: "",
            storedFileName: "",
            sourceMode: .copiedIntoLibrary,
            format: .unknown,
            durationMilliseconds: -1,
            createdAtUnixSeconds: 1_782_950_500,
            playbackSettings: CustomSoundPlaybackSettings()
        )
        let store = CustomSoundStore(snapshot: CustomSoundStoreSnapshot(
            files: [Self.permissionTone, Self.permissionTone, invalidFile],
            assignments: [.permission: "custom.permission", .failure: "missing.custom"],
            hasLoaded: true,
            isStarted: true,
            manifest: CustomSoundLibraryManifest(
                schemaVersion: 1,
                soundIds: ["custom.permission", "missing.manifest"],
                lastUpdatedUnixSeconds: 1_782_950_400,
                migrationVersion: 1
            )
        ))

        XCTAssertEqual(store.file(id: "custom.permission"), Self.permissionTone)
        XCTAssertEqual(store.assignedFile(for: .permission), Self.permissionTone)
        XCTAssertNil(store.assignedFile(for: .failure))
        XCTAssertEqual(
            store.validationReport.issues.map(\.kind),
            [
                .duplicateFileId,
                .invalidFile,
                .missingAssignedFile,
                .manifestReferencesMissingFile,
            ]
        )
    }

    func testCustomSoundStoreDiagnosticSummaryRedactsPrivateState() {
        let store = CustomSoundStore(snapshot: CustomSoundStoreSnapshot(
            files: [Self.permissionTone],
            assignments: [.permission: "custom.permission"],
            lastImportError: "failed to import /Users/admin/private/permission.wav",
            hasLoaded: true,
            isStarted: true,
            libraryDirectory: "/Users/admin/Library/Application Support/MyVibeIsland/Sounds"
        ))

        let summary = store.diagnosticSummary

        XCTAssertEqual(summary.fileCount, 1)
        XCTAssertEqual(summary.assignmentCount, 1)
        XCTAssertTrue(summary.hasLastImportError)
        XCTAssertTrue(summary.hasLibraryDirectory)
        XCTAssertTrue(summary.hasLoaded)
        XCTAssertTrue(summary.isStarted)
    }

    func testCustomSoundFileDiagnosticSummaryDoesNotExposeStoredFileName() throws {
        let file = CustomSoundFile(
            id: "custom.external",
            displayName: "External Tone",
            storedFileName: "/Users/admin/private/external-tone.wav",
            sourceMode: .referencedInPlace,
            format: .wav,
            durationMilliseconds: 1_200,
            createdAtUnixSeconds: 1_782_950_500,
            playbackSettings: CustomSoundPlaybackSettings(isEnabled: false)
        )

        let summary = file.diagnosticSummary
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8) ?? ""

        XCTAssertEqual(summary.sourceMode, .referencedInPlace)
        XCTAssertEqual(summary.format, .wav)
        XCTAssertTrue(summary.hasStoredFileReference)
        XCTAssertTrue(summary.hasDuration)
        XCTAssertFalse(summary.isPlaybackEnabled)
        XCTAssertFalse(encoded.contains("/Users/admin/private/external-tone.wav"))
        XCTAssertFalse(encoded.contains("External Tone"))
    }

    private static let permissionTone = CustomSoundFile(
        id: "custom.permission",
        displayName: "Permission Private",
        storedFileName: "permission-private.wav",
        sourceMode: .copiedIntoLibrary,
        format: .wav,
        durationMilliseconds: 900,
        createdAtUnixSeconds: 1_782_950_400,
        playbackSettings: CustomSoundPlaybackSettings(volume: 0.8)
    )

    private struct CustomSoundDiagnosticsFixture: Codable, Equatable {
        let storeDiagnosticSummary: CustomSoundStoreDiagnosticSummary
        let validationReport: CustomSoundStoreValidationReport
        let externalFileDiagnosticSummary: CustomSoundFileDiagnosticSummary
    }
}
