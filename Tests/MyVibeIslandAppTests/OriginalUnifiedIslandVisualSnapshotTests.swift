import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

@MainActor
final class OriginalUnifiedIslandVisualSnapshotTests: XCTestCase {
    func testWritesDeterministicCompactPeekAndExpandedSnapshotsWhenRequested() throws {
        guard let outputDirectory = ProcessInfo.processInfo.environment["VIBE_VISUAL_OUTPUT_DIR"] else {
            throw XCTSkip("Set VIBE_VISUAL_OUTPUT_DIR to write visual snapshots.")
        }

        let renderer = MyVibeIslandAppKitOriginalUnifiedHostingRenderer(
            onNavigateSwitcher: { _ in },
            onSubmitSwitcher: {},
            onCollapseSwitcher: {},
            onRequestFocus: {},
            onReleaseFocus: {}
        )
        let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let view = try XCTUnwrap(renderer.render(compactRenderList(), screen: screen))
        let window = makeWindow(contentView: view)
        defer { window.close() }

        try writeSnapshot(view: view, to: directory.appendingPathComponent("compact.png"))
        _ = try XCTUnwrap(renderer.renderPeek(
            .peek(
                OriginalPeekNotification(
                    id: "peek-1",
                    title: "Done",
                    detail: "Task completed",
                    provider: .openai,
                    level: .info
                ),
                kind: .taskComplete
            ),
            compactRenderList: compactRenderList(),
            screen: screen
        ))
        try writeSnapshot(view: view, to: directory.appendingPathComponent("peek.png"))
        _ = try XCTUnwrap(renderer.render(expandedRenderList(), screen: screen))
        try writeSnapshot(view: view, to: directory.appendingPathComponent("expanded.png"))
    }

    private func makeWindow(contentView view: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: view.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.contentView = view
        window.orderFrontRegardless()
        return window
    }

    private func writeSnapshot(view: NSView, to fileURL: URL) throws {
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.7))
        view.layoutSubtreeIfNeeded()

        let representation = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width),
            pixelsHigh: Int(view.bounds.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        view.cacheDisplay(in: view.bounds, to: representation)
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try data.write(to: fileURL, options: .atomic)
    }

    private func compactRenderList() -> IslandSurfaceRenderList {
        let session = sessions[0]
        return IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: [session],
            visibleSections: [.compactPill],
            displayStatus: .closed,
            layoutMode: .compact,
            onboardingStep: nil,
            primarySessionIds: [session.id],
            focusedSessionId: session.id
        ))
    }

    private func expandedRenderList() -> IslandSurfaceRenderList {
        IslandSurfaceRenderList(sections: IslandSurfaceSections(
            sessions: sessions,
            visibleSections: [.compactPill, .expandedPanel, .sessionCards],
            displayStatus: .expanded,
            layoutMode: .expanded,
            onboardingStep: nil,
            primarySessionIds: sessions.map(\.id),
            focusedSessionId: sessions[0].id
        ))
    }

    private var sessions: [AgentSession] {
        [
            AgentSession(
                id: "analysis-session",
                source: "codex",
                cwd: "/Users/admin/code/opensource/my-vibe-island",
                model: "gpt-5.6-sol",
                activeTool: "functions.exec",
                activitySummary: "Comparing the accepted visual baseline",
                originalStatus: .processing,
                lastAssistantMessage: "Freeze identical session input before measuring pixel differences.",
                updatedAt: Date(timeIntervalSince1970: 1_720_000_000),
                repoName: "my-vibe-island",
                firstUserMessage: "Make the session presentation match Vibe Island.",
                lastUserMessage: "Compare pixels, text, layout, and content.",
                redactionLevel: .metadataOnly
            ),
            AgentSession(
                id: "implementation-session",
                source: "claude",
                cwd: "/Users/admin/code/opensource/open-vibe-island",
                model: "claude-sonnet-4",
                activeTool: "Edit",
                activitySummary: "Implementing deterministic session cards",
                originalStatus: .processing,
                lastAssistantMessage: "The current implementation keeps the newest output visible.",
                updatedAt: Date(timeIntervalSince1970: 1_719_999_940),
                repoName: "open-vibe-island",
                firstUserMessage: "Use the existing bridge session data.",
                lastUserMessage: "Show the latest assistant content.",
                redactionLevel: .metadataOnly
            ),
            AgentSession(
                id: "review-session",
                source: "codex",
                cwd: "/Users/admin/code/opensource",
                model: "gpt-5.6-sol",
                activitySummary: "Reviewing visual parity evidence",
                originalStatus: .waitingForInput,
                lastAssistantMessage: "Layout matches; content ordering still requires verification.",
                updatedAt: Date(timeIntervalSince1970: 1_719_999_880),
                repoName: "opensource",
                firstUserMessage: "Review the expanded island.",
                lastUserMessage: "List every visible difference.",
                redactionLevel: .metadataOnly
            ),
            AgentSession(
                id: "completed-session",
                source: "claude",
                cwd: "/Users/admin/code/opensource/my-vibe-island",
                model: "claude-opus-4",
                activitySummary: "Visual review completed",
                originalStatus: .ended,
                lastAssistantMessage: "APPROVED",
                updatedAt: Date(timeIntervalSince1970: 1_719_999_820),
                repoName: "my-vibe-island",
                firstUserMessage: "Perform the final visual review.",
                lastUserMessage: "Approve only when the screenshots match.",
                hasUnreadCompletion: true,
                redactionLevel: .metadataOnly
            )
        ]
    }

    private var screen: OriginalNSScreenMetricsInput {
        OriginalNSScreenMetricsInput(
            safeAreaTopInset: 32,
            frameWidth: 1512,
            auxiliaryTopLeftWidth: 663,
            auxiliaryTopRightWidth: 664,
            screenFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: DisplayFrame(x: 0, y: 0, width: 1512, height: 949)
        )
    }
}
