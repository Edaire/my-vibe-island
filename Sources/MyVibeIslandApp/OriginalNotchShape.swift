import SwiftUI

public struct OriginalNotchShape: Shape {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY
        let top = topCornerRadius
        let bottom = bottomCornerRadius

        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY))
        path.addQuadCurve(
            to: CGPoint(x: minX + top, y: minY + top),
            control: CGPoint(x: minX + top, y: minY)
        )
        path.addLine(to: CGPoint(x: minX + top, y: maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: minX + top + bottom, y: maxY),
            control: CGPoint(x: minX + top, y: maxY)
        )
        path.addLine(to: CGPoint(x: maxX - top - bottom, y: maxY))
        path.addQuadCurve(
            to: CGPoint(x: maxX - top, y: maxY - bottom),
            control: CGPoint(x: maxX - top, y: maxY)
        )
        path.addLine(to: CGPoint(x: maxX - top, y: minY + top))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY),
            control: CGPoint(x: maxX - top, y: minY)
        )
        path.addLine(to: CGPoint(x: minX, y: minY))
        return path
    }
}
