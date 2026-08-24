import Combine
import MyVibeIslandCore
import SwiftUI

public struct OriginalPixelStatusIconView: View {
    public let status: OriginalPixelStatusCompact
    @State private var phase = 0
    private let timer = Timer.publish(
        every: 0.15,
        tolerance: nil,
        on: .main,
        in: .common,
        options: nil
    ).autoconnect()

    public init(status: OriginalPixelStatusCompact) {
        self.status = status
    }

    public var body: some View {
        Canvas(
            opaque: false,
            colorMode: .nonLinear,
            rendersAsynchronously: false
        ) { context, size in
            let frame = OriginalPixelStatusCompact.frame(for: status, at: phase)
            let unit = min(size.width / 13, size.height / 8)
            context.translateBy(
                x: (size.width - 13 * unit) / 2,
                y: (size.height - 8 * unit) / 2
            )

            for sample in Self.renderingSamples(frame.samples) {
                let rect = CGRect(
                    x: CGFloat(sample.coordinate.x) * unit + 0.15,
                    y: CGFloat(sample.coordinate.y) * unit + 0.15,
                    width: unit - 0.3,
                    height: unit - 0.3
                )
                let color = Color(
                    red: sample.color.red,
                    green: sample.color.green,
                    blue: sample.color.blue,
                    opacity: sample.opacity
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .onReceive(timer) { _ in
            phase = Self.nextPhase(after: phase)
        }
    }

    static func nextPhase(after phase: Int) -> Int {
        (phase + 1) % 72
    }

    static func renderingSamples(_ samples: [OriginalPixelSample]) -> [OriginalPixelSample] {
        let black = OriginalPixelColor(red: 0, green: 0, blue: 0)
        return samples.filter { $0.color != black } + samples.filter { $0.color == black }
    }
}
