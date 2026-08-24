import MyVibeIslandCore
import SwiftUI

public struct OriginalPixelStatusIconCompactView: View {
    public let status: OriginalPixelStatusCompact

    public init(status: OriginalPixelStatusCompact) {
        self.status = status
    }

    public var body: some View {
        Canvas(
            opaque: false,
            colorMode: .nonLinear,
            rendersAsynchronously: false
        ) { context, size in
            let frame = OriginalPixelStatusIconCompact(status: status).frame
            let unit = min(size.width, size.height) / 8
            context.translateBy(
                x: (size.width - 8 * unit) / 2,
                y: (size.height - 8 * unit) / 2
            )

            for sample in frame.primarySamples + frame.blackSamples {
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
    }
}
