import MyVibeIslandCore
import SwiftUI

/// Shared geometry recovered from the common VibeIsland card and pill components.
struct OriginalIslandComponentTokens: Equatable {
    let cardCornerRadius: CGFloat
    let cardHorizontalInset: CGFloat
    let cardVerticalInset: CGFloat
    let pillHorizontalInset: CGFloat
    let pillVerticalInset: CGFloat
    let pillFontSize: CGFloat
    let completionHeaderOpacity: Double
    let completionViewportOpacity: Double

    static let original = Self(
        cardCornerRadius: 10,
        cardHorizontalInset: 8,
        cardVerticalInset: 8,
        pillHorizontalInset: 5,
        pillVerticalInset: 2,
        pillFontSize: 9,
        completionHeaderOpacity: 0.10,
        completionViewportOpacity: 0.08
    )
}

struct OriginalCardContainerView<Content: View>: View {
    let plan: OriginalSessionCardShellPlan
    let fill: OriginalSessionCardShellColor
    let stroke: OriginalSessionCardShellColor
    let animationValue: Bool
    private let content: Content
    private let tokens = OriginalIslandComponentTokens.original

    init(
        plan: OriginalSessionCardShellPlan,
        fill: OriginalSessionCardShellColor,
        stroke: OriginalSessionCardShellColor,
        animationValue: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.plan = plan
        self.fill = fill
        self.stroke = stroke
        self.animationValue = animationValue
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, tokens.cardHorizontalInset)
            .padding(.vertical, plan.axis == .horizontal ? 6 : tokens.cardVerticalInset)
            .background {
                RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
                    .fill(color(fill))
            }
            .overlay {
                RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
                    .stroke(color(stroke), lineWidth: 1)
            }
            .animation(.easeInOut(duration: 0.15), value: animationValue)
    }

    private func color(_ value: OriginalSessionCardShellColor) -> Color {
        switch value {
        case .clear: .clear
        case let .white(opacity): Color.white.opacity(opacity)
        }
    }
}

enum OriginalTagPillPalette: Equatable {
    case codex
    case claude
    case neutral

    static func resolve(_ value: String) -> Self {
        switch value.lowercased() {
        case "codex": .codex
        case "claude": .claude
        default: .neutral
        }
    }

    var foreground: Color {
        switch self {
        case .codex: Color.blue.opacity(0.9)
        // Observed from the original Vibe Island 3 expanded list.
        case .claude: Color(red: 0.82, green: 0.36, blue: 0.16).opacity(0.95)
        case .neutral: Color.white.opacity(0.62)
        }
    }

    var background: Color {
        switch self {
        case .codex: Color.blue.opacity(0.16)
        case .claude: Color(red: 0.55, green: 0.20, blue: 0.06).opacity(0.23)
        case .neutral: Color.white.opacity(0.08)
        }
    }
}

struct OriginalTagPill: View {
    let value: String
    private let tokens = OriginalIslandComponentTokens.original

    var body: some View {
        let palette = OriginalTagPillPalette.resolve(value)
        Text(value)
            .font(.system(size: tokens.pillFontSize, weight: .medium))
            .foregroundStyle(palette.foreground)
            .padding(.horizontal, tokens.pillHorizontalInset)
            .padding(.vertical, tokens.pillVerticalInset)
            .background(palette.background, in: Capsule())
    }
}

enum OriginalExpandedUsageWaitingHeaderPlan: Equatable {
    case waitingForCodexActivity

    static func resolve(
        usageInfoBar: UsageInfoBar?,
        rows: [OriginalExpandedSessionRow]
    ) -> Self? {
        guard let usageInfoBar,
              usageInfoBar.status == .waiting || usageInfoBar.status == .unavailable,
              rows.first?.session.source.caseInsensitiveCompare("codex") == .orderedSame
        else {
            return nil
        }
        return .waitingForCodexActivity
    }
}

struct OriginalExpandedUsageWaitingHeaderView: View {
    let plan: OriginalExpandedUsageWaitingHeaderPlan

    var body: some View {
        switch plan {
        case .waitingForCodexActivity:
            HStack(spacing: 4) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 9, weight: .regular))
                Text("等待 Codex 活动")
                    .font(.system(size: 10, weight: .regular))
            }
            .foregroundStyle(Color.white.opacity(0.42))
        }
    }
}

/// IDA ties this compact blue symbol to the terminal-jump action. It shares
/// the header's visual language without reserving a separate control column.
struct OriginalExpandedHeaderJumpControl: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.blue.opacity(0.9))
                .frame(width: 16, height: 14)
                .background(Color.blue.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("前往终端")
    }
}

struct OriginalJumpToTerminalPill: View {
    let toolName: String
    let command: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "terminal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.58))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("请在终端中操作")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.80))
                Text("\(toolName): \(command)")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: action) {
                HStack(spacing: 4) {
                    Text("前往终端")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.76))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("前往终端")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 53, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// The orange command/reason surface in the captured terminal-routed Codex row.
struct OriginalApprovalCommandSurface: View {
    let command: String
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("$ \(command)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(reason)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.54))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.orange.opacity(0.16), lineWidth: 1)
        }
    }
}

struct OriginalCompletionCardView<Header: View, Viewport: View>: View {
    private let header: Header
    private let viewport: Viewport
    private let tokens = OriginalIslandComponentTokens.original

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder viewport: () -> Viewport
    ) {
        self.header = header()
        self.viewport = viewport()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(tokens.completionHeaderOpacity))
            viewport
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(tokens.completionViewportOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(tokens.completionHeaderOpacity), lineWidth: 1)
        }
    }
}
