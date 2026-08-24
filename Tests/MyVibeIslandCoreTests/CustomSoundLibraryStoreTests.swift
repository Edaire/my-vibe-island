import Foundation
import XCTest
@testable import MyVibeIslandCore

final class CustomSoundLibraryStoreTests: XCTestCase {
    func testImportCopiesSupportedWAVWithSafeUniqueLibraryName() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source/My Tone.wav")
        try write(Data("wav-data".utf8), to: source)
        let store = CustomSoundLibraryStore(libraryDirectory: root.appendingPathComponent("library"))

        let sound = try store.importFile(at: source)
        let copiedURL = try store.fileURL(forStoredFileName: sound.storedFileName)

        XCTAssertEqual(sound.sourceMode, .copiedIntoLibrary)
        XCTAssertEqual(sound.format, .wav)
        XCTAssertEqual(sound.displayName, "My Tone")
        XCTAssertTrue(UUID(uuidString: sound.id) != nil)
        XCTAssertEqual(copiedURL.pathExtension.lowercased(), "wav")
        XCTAssertEqual(copiedURL.deletingPathExtension().lastPathComponent, sound.id)
        XCTAssertEqual(try Data(contentsOf: copiedURL), Data("wav-data".utf8))
    }

    func testImportAcceptsAIFFAndReloadsManifest() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source/tone.aiff")
        try write(Data("aiff-data".utf8), to: source)
        let library = root.appendingPathComponent("library")

        let imported = try CustomSoundLibraryStore(libraryDirectory: library).importFile(at: source)
        let reloaded = try CustomSoundLibraryStore(libraryDirectory: library).loadSnapshot()

        XCTAssertEqual(reloaded.files, [imported])
        XCTAssertEqual(reloaded.manifest.soundIds, [imported.id])
        XCTAssertEqual(reloaded.libraryDirectory, library.standardizedFileURL.path)
    }

    func testImportOfIdenticalContentIsIdempotent() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source/tone.wav")
        try write(Data("same-content".utf8), to: source)
        let store = CustomSoundLibraryStore(libraryDirectory: root.appendingPathComponent("library"))

        let first = try store.importFile(at: source)
        let second = try store.importFile(at: source)

        XCTAssertEqual(second, first)
        XCTAssertEqual(try store.loadSnapshot().files, [first])
    }

    func testImportRejectsUnsupportedFormats() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("source/tone.mp3")
        try write(Data("not-supported".utf8), to: source)
        let store = CustomSoundLibraryStore(libraryDirectory: root.appendingPathComponent("library"))

        XCTAssertThrowsError(try store.importFile(at: source)) { error in
            XCTAssertEqual(error as? CustomSoundLibraryStoreError, .unsupportedFormat)
        }
    }

    func testLibraryFileURLsRejectTraversalNames() throws {
        let root = try temporaryDirectory()
        let store = CustomSoundLibraryStore(libraryDirectory: root.appendingPathComponent("library"))

        XCTAssertThrowsError(try store.fileURL(forStoredFileName: "../outside.wav")) { error in
            XCTAssertEqual(error as? CustomSoundLibraryStoreError, .invalidStoredFileName)
        }
        XCTAssertThrowsError(try store.fileURL(forStoredFileName: "/tmp/outside.wav")) { error in
            XCTAssertEqual(error as? CustomSoundLibraryStoreError, .invalidStoredFileName)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("my-vibe-island-custom-sound-library-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }
}
