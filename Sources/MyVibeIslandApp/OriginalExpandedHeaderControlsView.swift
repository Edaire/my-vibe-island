import SwiftUI

enum OriginalExpandedHeaderControlAction: Equatable {
    case toggleSound
    case openSettings
}

struct OriginalExpandedHeaderControlsView: View {
    private let layout = OriginalExpandedSessionLayoutPlan.original
    private static let controlFrame = OriginalExpandedSessionLayoutPlan.original.controlFrame
    private static let controlSpacing = OriginalExpandedSessionLayoutPlan.original.controlSpacing
    static let reservedWidth = 2 * controlFrame + controlSpacing

    let soundEnabled: Bool
    let onToggleSound: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: CGFloat(layout.controlSpacing)) {
            Button {
                perform(.toggleSound)
            } label: {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: CGFloat(layout.controlGlyph), weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(width: CGFloat(layout.controlFrame), height: CGFloat(layout.controlFrame))
            }
            .buttonStyle(.plain)
            .help("Toggle sounds")

            Button {
                perform(.openSettings)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: CGFloat(layout.controlGlyph), weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(width: CGFloat(layout.controlFrame), height: CGFloat(layout.controlFrame))
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
    }

    func perform(_ action: OriginalExpandedHeaderControlAction) {
        switch action {
        case .toggleSound:
            onToggleSound()
        case .openSettings:
            onOpenSettings()
        }
    }
}
