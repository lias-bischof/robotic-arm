import SwiftUI

func createPoint(_ wx: CGFloat, _ wz: CGFloat, mid: CGPoint, extent: CGFloat, rect: CGRect) -> CGPoint {
    CGPoint(
        x: mid.x + wx / extent * (rect.width / 2),
        y: mid.y + wz / extent * (rect.height / 2)
    )
}
