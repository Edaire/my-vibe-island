import MyVibeIslandCore
import SwiftUI

public struct MyVibeIslandOnboardingSelection: Equatable, Sendable {
    public let palette: MyVibeIslandOnboardingPalette
    public let showCompletedTasks: Bool
    public let playNotificationSounds: Bool

    public init(
        palette: MyVibeIslandOnboardingPalette = .electric,
        showCompletedTasks: Bool = true,
        playNotificationSounds: Bool = true
    ) {
        self.palette = palette
        self.showCompletedTasks = showCompletedTasks
        self.playNotificationSounds = playNotificationSounds
    }
}

public struct MyVibeIslandAppKitProductionFullscreenView: View {
    private enum Phase {
        case welcome
        case demo
    }

    private let onComplete: () -> Void
    @State private var phase = Phase.welcome

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.039, blue: 0.047)
                .ignoresSafeArea()

            switch phase {
            case .welcome:
                VStack(spacing: 20) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(.cyan)
                    Text("My Vibe Island")
                        .font(.system(size: 42, weight: .bold))
                    Text("Every local coding agent, focused in one place.")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                    Button("See It in Action") {
                        phase = .demo
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("my-vibe-island.onboarding.fullscreen.demo")
                }
            case .demo:
                VStack(spacing: 28) {
                    HStack(spacing: 14) {
                        ForEach(MyVibeIslandOnboardingDemoPresentation.cards) { card in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(card.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Divider()
                                Text(card.body)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(16)
                            .frame(maxWidth: 280, minHeight: 150, alignment: .topLeading)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.12))
                            }
                        }
                    }
                    Text("All your AI agents, one Dynamic Island.")
                        .font(.system(size: 26, weight: .bold))
                    Button("Continue") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("my-vibe-island.onboarding.fullscreen.continue")
                }
                .padding(40)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("my-vibe-island.onboarding.fullscreen")
    }
}

public struct MyVibeIslandAppKitProductionCardView: View {
    private enum Phase {
        case vibe
        case config
    }

    private let onComplete: (MyVibeIslandOnboardingSelection) -> Void
    @State private var phase = Phase.vibe
    @State private var palette = MyVibeIslandOnboardingPalette.electric
    @State private var showCompletion = true
    @State private var playSounds = true

    public init(onComplete: @escaping (MyVibeIslandOnboardingSelection) -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 24) {
            switch phase {
            case .vibe:
                Text("Choose your vibe")
                    .font(.system(size: 28, weight: .bold))
                Text("Pick the accent used by your island.")
                    .foregroundStyle(.secondary)
                Picker("Vibe", selection: $palette) {
                    ForEach(MyVibeIslandOnboardingPalette.allCases, id: \.self) { value in
                        Text(value.rawValue.capitalized).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("my-vibe-island.onboarding.card.vibe")
                Button("Continue") {
                    phase = .config
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("my-vibe-island.onboarding.card.config")
            case .config:
                Text("Make it yours")
                    .font(.system(size: 28, weight: .bold))
                VStack(spacing: 16) {
                    Toggle("Show completed tasks", isOn: $showCompletion)
                    Toggle("Play notification sounds", isOn: $playSounds)
                }
                .toggleStyle(.switch)
                Button("Continue") {
                    onComplete(MyVibeIslandOnboardingSelection(
                        palette: palette,
                        showCompletedTasks: showCompletion,
                        playNotificationSounds: playSounds
                    ))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("my-vibe-island.onboarding.card.continue")
            }
        }
        .padding(42)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.035, green: 0.039, blue: 0.047))
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("my-vibe-island.onboarding.card")
    }
}

public struct MyVibeIslandAppKitProductionReadyView: View {
    public let state: OnboardingReadyWindowState
    private let onFinish: () -> Void

    public init(
        state: OnboardingReadyWindowState = OnboardingReadyWindowState(
            readinessOutcome: .ready,
            nextActions: [.startUsing]
        ),
        onFinish: @escaping () -> Void
    ) {
        self.state = state
        self.onFinish = onFinish
    }

    public var body: some View {
        StepReadyView(
            state: state,
            onFinish: finish
        )
    }

    public func finish() {
        guard state.nextActions.contains(.startUsing)
            || state.readinessOutcome == .demoOnly
        else { return }
        onFinish()
    }
}
