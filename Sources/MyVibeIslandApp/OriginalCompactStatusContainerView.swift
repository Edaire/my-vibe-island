import MyVibeIslandCore
import SwiftUI

public struct OriginalCompactStatusContainerView: View {
    public let status: OriginalPixelStatusCompact
    public let isMinimized: Bool
    public let completionFlashProgress: Double

    static let completionGlowColor = Color(red: 0.13, green: 0.77, blue: 0.37)

    public init(
        status: OriginalPixelStatusCompact,
        isMinimized: Bool,
        completionFlashProgress: Double
    ) {
        self.status = status
        self.isMinimized = isMinimized
        self.completionFlashProgress = completionFlashProgress
    }

    public var body: some View {
        let glowColor = Self.glowColor(for: status)

        Group {
            if isMinimized {
                OriginalPixelStatusIconCompactView(status: status)
                    .frame(width: 20, height: 20)
                    .shadow(color: glowColor.opacity(0.5), radius: 2, x: 0, y: 0)
                    .shadow(color: glowColor.opacity(0.25), radius: 6, x: 0, y: 0)
            } else {
                OriginalPixelStatusIconView(status: status)
                    .frame(width: 32, height: 20)
                    .shadow(color: glowColor.opacity(0.5), radius: 3, x: 0, y: 0)
                    .shadow(color: glowColor.opacity(0.2), radius: 8, x: 0, y: 0)
            }
        }
        .shadow(color: Self.completionGlowColor.opacity(completionFlashProgress), radius: 7, x: 0, y: 0)
        .shadow(color: Self.completionGlowColor.opacity(0.6 * completionFlashProgress), radius: 13, x: 0, y: 0)
        .scaleEffect(CGFloat(1 + 0.18 * completionFlashProgress), anchor: .center)
    }

    static func glowColor(for status: OriginalPixelStatusCompact) -> Color {
        switch status {
        case .waitingForInput:
            .green
        case .processing, .runningTool:
            .blue
        case .thinking, .compacting:
            .purple
        case .waitingForApproval, .question:
            .orange
        case .ended, .unknown:
            .gray
        }
    }
}
