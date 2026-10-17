import Foundation
import SwiftUI

func createVector(_ context: inout GraphicsContext, from origin: CGPoint, to tip: CGPoint, color: Color) {
    let dx = tip.x - origin.x
    let dy = tip.y - origin.y
    let length = sqrt(dx * dx + dy * dy)

    var shaft = CPath()
    shaft.move(to: origin)
    shaft.addLine(to: tip)
    context.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: 1))

    guard length > 0 else { return }
    let ux = dx / length
    let uy = dy / length
    let base = CGPoint(x: tip.x - ux * 6, y: tip.y - uy * 6)
    let perp = CGPoint(x: -uy * 6 * 0.4, y: ux * 6 * 0.4)
    var head = CPath()
    head.move(to: tip)
    head.addLine(to: CGPoint(x: base.x + perp.x, y: base.y + perp.y))
    head.addLine(to: CGPoint(x: base.x - perp.x, y: base.y - perp.y))
    head.closeSubpath()
    context.fill(head, with: .color(color))
}
