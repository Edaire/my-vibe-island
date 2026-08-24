import MyVibeIslandCore
import SwiftUI

public struct MyVibeIslandOnboardingDemoCardPresentation: Identifiable, Equatable, Sendable {
    public let bundleIdentifier: String
    public let title: String
    public let symbol: String?
    public let body: String

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, title: String, symbol: String? = nil, body: String) {
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.symbol = symbol
        self.body = body
    }
}

public struct MyVibeIslandOnboardingCaptionPresentation: Equatable, Sendable {
    public let time: Double
    public let label: String
    public let main: String
    public let sub: String

    public init(time: Double, label: String, main: String, sub: String) {
        self.time = time
        self.label = label
        self.main = main
        self.sub = sub
    }
}

public enum MyVibeIslandOnboardingDemoTimelineAction: Equatable, Sendable {
    case showCaption(Int)
    case showCard(Int)
    case finish
}

public struct MyVibeIslandOnboardingDemoTimelineEvent: Equatable, Sendable {
    public let time: Double
    public let action: MyVibeIslandOnboardingDemoTimelineAction

    public init(time: Double, action: MyVibeIslandOnboardingDemoTimelineAction) {
        self.time = time
        self.action = action
    }
}

public struct MyVibeIslandOnboardingDemoViewState: Equatable, Sendable {
    public let visibleCardCount: Int
    public let captionIndex: Int?
    public let isFinished: Bool

    public static let initial = MyVibeIslandOnboardingDemoViewState(
        visibleCardCount: 0,
        captionIndex: nil,
        isFinished: false
    )

    public init(visibleCardCount: Int, captionIndex: Int?, isFinished: Bool) {
        self.visibleCardCount = max(0, min(visibleCardCount, MyVibeIslandOnboardingDemoPresentation.cards.count))
        self.captionIndex = captionIndex.flatMap {
            MyVibeIslandOnboardingDemoPresentation.captions.indices.contains($0) ? $0 : nil
        }
        self.isFinished = isFinished
    }

    public func applying(_ action: MyVibeIslandOnboardingDemoTimelineAction) -> Self {
        switch action {
        case let .showCaption(index):
            return Self(
                visibleCardCount: visibleCardCount,
                captionIndex: index,
                isFinished: isFinished
            )
        case let .showCard(index):
            return Self(
                visibleCardCount: max(visibleCardCount, index + 1),
                captionIndex: captionIndex,
                isFinished: isFinished
            )
        case .finish:
            return Self(
                visibleCardCount: visibleCardCount,
                captionIndex: captionIndex,
                isFinished: true
            )
        }
    }
}

public enum MyVibeIslandOnboardingDemoPresentation {
    public static let cards = [
        MyVibeIslandOnboardingDemoCardPresentation(
            bundleIdentifier: "com.mitchellh.ghostty",
            title: "vibe-island · Claude Code",
            body: "I'll add dark mode support to the app.\nRead(src/styles/theme.css)\nEdit(src/styles/theme.css)"
        ),
        MyVibeIslandOnboardingDemoCardPresentation(
            bundleIdentifier: "com.openai.codex",
            title: "Fix checkout bug · my-store",
            symbol: "hexagon",
            body: "Choose \"Allow\" once macOS requests permission."
        ),
        MyVibeIslandOnboardingDemoCardPresentation(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            title: "Package.swift — Cursor",
            symbol: "cursorarrow.rays",
            body: "Package.resolved"
        ),
    ]

    public static let captions = [
        MyVibeIslandOnboardingCaptionPresentation(
            time: 0.3,
            label: "1 / 4",
            main: "All your AI agents, one Dynamic Island.",
            sub: "Terminals, desktop apps, IDEs — every running session lives in the notch."
        ),
        MyVibeIslandOnboardingCaptionPresentation(
            time: 11.9,
            label: "2 / 4",
            main: "Approve without switching windows.",
            sub: "When an agent needs permission, it pops up right here. No context switching."
        ),
        MyVibeIslandOnboardingCaptionPresentation(
            time: 17.3,
            label: "3 / 4",
            main: "Know the moment it's done.",
            sub: "Finished tasks surface automatically — no hunting through terminal tabs."
        ),
    ]

    public static let timeline = [
        MyVibeIslandOnboardingDemoTimelineEvent(time: 0.3, action: .showCaption(0)),
        MyVibeIslandOnboardingDemoTimelineEvent(time: 1.0, action: .showCard(0)),
        MyVibeIslandOnboardingDemoTimelineEvent(time: 2.5, action: .showCard(1)),
        MyVibeIslandOnboardingDemoTimelineEvent(time: 4.0, action: .showCard(2)),
        MyVibeIslandOnboardingDemoTimelineEvent(time: 11.9, action: .showCaption(1)),
        MyVibeIslandOnboardingDemoTimelineEvent(time: 17.3, action: .showCaption(2)),
        MyVibeIslandOnboardingDemoTimelineEvent(time: 25.1, action: .finish),
    ]
}

public enum MyVibeIslandOnboardingReadyPresentation {
    public static let title = "Welcome aboard"
    public static let restartHint = "Restart any running sessions, or start a new one."
    public static let ctaTitle = "Start Vibing"
}

public enum MyVibeIslandOnboardingPalette: String, CaseIterable, Sendable {
    case electric
    case claude
    case aurora
    case royal
    case noir

    public static func next(excluding current: Self, selectionIndex: Int) -> Self {
        let candidates = allCases.filter { $0 != current }
        let index = Int(selectionIndex.magnitude % UInt(candidates.count))
        return candidates[index]
    }
}

public struct StepDemoView: View {
    public let state: OnboardingDemoRunnerState
    private let onNext: () -> Void

    @State private var viewState = MyVibeIslandOnboardingDemoViewState.initial

    public init(state: OnboardingDemoRunnerState, onNext: @escaping () -> Void) {
        self.state = state
        self.onNext = onNext
    }

    public var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.039, blue: 0.047)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                demoCards
                caption
            }
            .padding(36)
        }
        .preferredColorScheme(.dark)
        .task {
            await runTimeline()
        }
        .accessibilityIdentifier("my-vibe-island.onboarding.demo")
    }

    public func finish() {
        onNext()
    }

    private var demoCards: some View {
        HStack(alignment: .center, spacing: 14) {
            ForEach(Array(MyVibeIslandOnboardingDemoPresentation.cards.enumerated()), id: \.element.id) { index, card in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: appSymbol(for: card.bundleIdentifier))
                            .font(.system(size: 15, weight: .semibold))
                        Text(card.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let symbol = card.symbol {
                            Image(systemName: symbol)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    Text(card.body)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .opacity(index < viewState.visibleCardCount ? 1 : 0.16)
                .scaleEffect(index < viewState.visibleCardCount ? 1 : 0.96)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: viewState.visibleCardCount)
                .accessibilityIdentifier("my-vibe-island.onboarding.demo.card.\(index)")
            }
        }
    }

    @ViewBuilder
    private var caption: some View {
        if let captionIndex = viewState.captionIndex {
            let value = MyVibeIslandOnboardingDemoPresentation.captions[captionIndex]
            VStack(spacing: 8) {
                Text(value.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value.main)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(value.sub)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }
            .id(captionIndex)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Color.clear.frame(height: 88)
        }
    }

    private func runTimeline() async {
        var previousTime = 0.0
        for event in MyVibeIslandOnboardingDemoPresentation.timeline {
            guard !Task.isCancelled else { return }
            let delay = max(0, event.time - previousTime)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }

            let nextState = viewState.applying(event.action)
            withAnimation(.easeInOut(duration: 0.35)) {
                viewState = nextState
            }
            if nextState.isFinished {
                onNext()
            }
            previousTime = event.time
        }
    }

    private func appSymbol(for bundleIdentifier: String) -> String {
        switch bundleIdentifier {
        case "com.mitchellh.ghostty":
            return "terminal"
        case "com.openai.codex":
            return "sparkles"
        default:
            return "cursorarrow.rays"
        }
    }

}

public struct StepReadyView: View {
    public let state: OnboardingReadyWindowState
    private let onFinish: () -> Void
    private let paletteSelection: () -> Int

    @State private var appeared = false
    @State private var cardAppeared = false
    @State private var cardRotation = 8.0
    @State private var palette: MyVibeIslandOnboardingPalette

    public init(
        state: OnboardingReadyWindowState,
        initialPalette: MyVibeIslandOnboardingPalette = .electric,
        paletteSelection: @escaping () -> Int = { Int.random(in: 0..<Int.max) },
        onFinish: @escaping () -> Void
    ) {
        self.state = state
        self.onFinish = onFinish
        self.paletteSelection = paletteSelection
        _palette = State(initialValue: initialPalette)
    }

    public var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.039, blue: 0.047)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                editionCard
                    .opacity(cardAppeared ? 1 : 0.7)
                    .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(cardAppeared ? 1 : 0.9)

                Text(MyVibeIslandOnboardingReadyPresentation.title)
                    .font(.system(size: 28, weight: .bold))

                Text(MyVibeIslandOnboardingReadyPresentation.restartHint)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onFinish) {
                    HStack(spacing: 8) {
                        Text(MyVibeIslandOnboardingReadyPresentation.ctaTitle)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("my-vibe-island.onboarding.ready.finish")
            }
            .padding(40)
            .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .task {
            withAnimation(.easeIn(duration: 0.3)) {
                appeared = true
            }
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.65, blendDuration: 0)) {
                cardAppeared = true
                cardRotation = 0
            }
        }
        .accessibilityIdentifier("my-vibe-island.onboarding.ready")
    }

    public func finish() {
        onFinish()
    }

    private var editionCard: some View {
        let colors = paletteColors
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("MY VIBE ISLAND")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(colors.foreground.opacity(0.8))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                        palette = MyVibeIslandOnboardingPalette.next(
                            excluding: palette,
                            selectionIndex: paletteSelection()
                        )
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(colors.foreground)
                .help("Shuffle card colors")
                .accessibilityIdentifier("my-vibe-island.onboarding.ready.shuffle")
            }

            Spacer(minLength: 4)

            Text("READY")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(colors.foreground)
            Text("Local agents. One focused surface.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colors.foreground.opacity(0.72))
        }
        .padding(22)
        .frame(width: 360, height: 210, alignment: .topLeading)
        .background(colors.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(colors.accent)
                .frame(width: 6)
                .padding(.vertical, 18)
        }
        .shadow(color: .black.opacity(0.7), radius: 40, y: 20)
        .shadow(color: colors.accent.opacity(0.3), radius: 80, y: 30)
    }

    private var paletteColors: (background: Color, foreground: Color, accent: Color) {
        switch palette {
        case .electric:
            return (Color(red: 0.12, green: 0.16, blue: 0.22), .white, Color(red: 0.2, green: 0.82, blue: 0.92))
        case .claude:
            return (Color(red: 0.24, green: 0.18, blue: 0.16), .white, Color(red: 0.92, green: 0.46, blue: 0.28))
        case .aurora:
            return (Color(red: 0.08, green: 0.20, blue: 0.16), .white, Color(red: 0.36, green: 0.88, blue: 0.58))
        case .royal:
            return (Color(red: 0.16, green: 0.13, blue: 0.25), .white, Color(red: 0.64, green: 0.48, blue: 0.96))
        case .noir:
            return (Color(red: 0.08, green: 0.08, blue: 0.09), .white, Color(red: 0.72, green: 0.72, blue: 0.76))
        }
    }
}
