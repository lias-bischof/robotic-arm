import Foundation
import RealityKit
import AppKit

func createCircle(center: SIMD2<Float>, radius: Float, azimuth: Float, color: NSColor, thickness: Float, segments: Int = 64) -> Entity {
    let container = Entity()
    let step = (2 * Float.pi) / Float(segments)
    let center3 = uvlift(azimuth: azimuth, vector: center)

    for i in 0..<segments {
        let a0 = step * Float(i)
        let a1 = step * Float(i + 1)

        let p0 = center3 + uvlift(azimuth: azimuth, vector: SIMD2<Float>(radius * cos(a0), radius * sin(a0)))
        let p1 = center3 + uvlift(azimuth: azimuth, vector: SIMD2<Float>(radius * cos(a1), radius * sin(a1)))

        container.addChild(createLine(from: p0, to: p1, color: color, thickness: thickness))
    }

    return container
}
