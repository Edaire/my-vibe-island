import MyVibeIslandCore
import SwiftUI

public struct OriginalPeekNotificationRowAppearance: Codable, Equatable, Sendable {
    public let symbol: String
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(
        symbol: String,
        red: Double,
        green: Double,
        blue: Double,
        opacity: Double
    ) {
        self.symbol = symbol
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    public static func resolve(
        _ notification: OriginalPeekNotification
    ) -> OriginalPeekNotificationRowAppearance {
        if let provider = notification.provider {
            switch provider {
            case .anthropic:
                return .init(symbol: symbol(for: notification.level), red: 0.80, green: 0.61, blue: 0.48, opacity: 1)
            case .openai:
                return .init(symbol: symbol(for: notification.level), red: 0.06, green: 0.64, blue: 0.50, opacity: 1)
            case .google:
                return .init(symbol: symbol(for: notification.level), red: 0.26, green: 0.52, blue: 0.96, opacity: 1)
            case .zhipu:
                return .init(symbol: symbol(for: notification.level), red: 0.20, green: 0.60, blue: 0.90, opacity: 1)
            case .kimi:
                return .init(symbol: symbol(for: notification.level), red: 0.10, green: 0.37, blue: 1.00, opacity: 1)
            }
        }

        switch notification.level {
        case .info:
            return .init(symbol: "checkmark.circle.fill", red: 1, green: 1, blue: 1, opacity: 0.55)
        case .warning:
            return .init(symbol: "exclamationmark.triangle.fill", red: 0.98, green: 0.57, blue: 0.24, opacity: 1)
        case .critical:
            return .init(symbol: "exclamationmark.octagon.fill", red: 0.98, green: 0.45, blue: 0.09, opacity: 1)
        }
    }

    private static func symbol(for level: OriginalPeekLevel) -> String {
        switch level {
        case .info:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .critical:
            "exclamationmark.octagon.fill"
        }
    }
}

public struct OriginalPeekNotificationRowView: View {
    public let notification: OriginalPeekNotification

    public init(notification: OriginalPeekNotification) {
        self.notification = notification
    }

    public var body: some View {
        let appearance = OriginalPeekNotificationRowAppearance.resolve(notification)

        return HStack(alignment: .center, spacing: 6) {
            Image(systemName: appearance.symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 14)
                .foregroundStyle(Color(red: appearance.red, green: appearance.green, blue: appearance.blue).opacity(appearance.opacity))

            VStack(alignment: .leading, spacing: 0) {
                Text(notification.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)
                Text(notification.detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 4)
    }
}
