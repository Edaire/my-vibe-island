import CoreGraphics
import SwiftUI
import XCTest
@testable import MyVibeIslandApp

final class OriginalNotchShapeTests: XCTestCase {
    func testPathMatchesRecoveredQuadraticCommandsForOffsetRectAndDistinctRadii() {
        let rect = CGRect(x: 11, y: 17, width: 101, height: 53)

        let elements = OriginalNotchShape(
            topCornerRadius: 7,
            bottomCornerRadius: 13
        ).path(in: rect).cgPath.elements

        XCTAssertEqual(elements, [
            .move(CGPoint(x: 11, y: 17)),
            .quad(control: CGPoint(x: 18, y: 17), end: CGPoint(x: 18, y: 24)),
            .line(CGPoint(x: 18, y: 57)),
            .quad(control: CGPoint(x: 18, y: 70), end: CGPoint(x: 31, y: 70)),
            .line(CGPoint(x: 92, y: 70)),
            .quad(control: CGPoint(x: 105, y: 70), end: CGPoint(x: 105, y: 57)),
            .line(CGPoint(x: 105, y: 24)),
            .quad(control: CGPoint(x: 105, y: 17), end: CGPoint(x: 112, y: 17)),
            .line(CGPoint(x: 11, y: 17)),
        ])
    }
}

private enum PathElement: Equatable {
    case move(CGPoint)
    case line(CGPoint)
    case quad(control: CGPoint, end: CGPoint)
    case cubic(control1: CGPoint, control2: CGPoint, end: CGPoint)
    case close
}

private extension CGPath {
    var elements: [PathElement] {
        var elements: [PathElement] = []
        applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                elements.append(.move(element.pointee.points[0]))
            case .addLineToPoint:
                elements.append(.line(element.pointee.points[0]))
            case .addQuadCurveToPoint:
                elements.append(.quad(
                    control: element.pointee.points[0],
                    end: element.pointee.points[1]
                ))
            case .addCurveToPoint:
                elements.append(.cubic(
                    control1: element.pointee.points[0],
                    control2: element.pointee.points[1],
                    end: element.pointee.points[2]
                ))
            case .closeSubpath:
                elements.append(.close)
            @unknown default:
                XCTFail("Unknown CGPath element type")
            }
        }
        return elements
    }
}
