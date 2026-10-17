import AppKit
import RealityKit

func createGrid(_ radius: Float = 30, _ spacing: Float = 5, _ emphasis: Float = 10) -> Entity {
    let container = Entity()
    let cells = Int((radius * 2 / spacing).rounded())
    let tickSpacing: Float = 10
    
    for row in 0...cells {
        let z = Float(row) * spacing - radius
        let major = abs(z.truncatingRemainder(dividingBy: emphasis)) < 0.001
        let start = SIMD3<Float>(-radius, 0, z)
        let end = SIMD3<Float>(radius, 0, z)
        let line = createLine(from: start, to: end, color: NSColor.secondary, thickness: major ? 0.2 : 0.1)
        container.addChild(line)
        if abs(z.truncatingRemainder(dividingBy: tickSpacing)) < 0.001 {
            let tick = createLine(
                from: SIMD3<Float>(-0.5, 0.5, z),
                to: SIMD3<Float>(0.5, 0.5, z),
                color: NSColor.secondary,
                thickness: 0.05
            )
            container.addChild(tick)
            if z != 0 {
                let label = createText(String(format: "%.0f", z), position: SIMD3<Float>(1.5, 0.5, z), color: NSColor.tertiary, size: 1.5)
                container.addChild(label)
            }
        }
    }
    
    for col in 0...cells {
        let x = Float(col) * spacing - radius
        let major = abs(x.truncatingRemainder(dividingBy: emphasis)) < 0.001
        let start = SIMD3<Float>(x, 0, -radius)
        let end = SIMD3<Float>(x, 0, radius)
        let line = createLine(from: start, to: end, color: NSColor.secondary, thickness: major ? 0.2 : 0.1)
        container.addChild(line)
        if abs(x.truncatingRemainder(dividingBy: tickSpacing)) < 0.001 {
            let tick = createLine(
                from: SIMD3<Float>(x, 0.5, -0.5),
                to: SIMD3<Float>(x, 0.5, 0.5),
                color: NSColor.secondary,
                thickness: 0.05
            )
            container.addChild(tick)
            if x != 0 {
                let label = createText(String(format: "%.0f", x), position: SIMD3<Float>(x, 0.5, 1.5), color: NSColor.tertiary, size: 1.5)
                container.addChild(label)
            }
        }
    }
    
    let xaxis = createLine(
        from: SIMD3<Float>(-radius - spacing, 0.15, 0),
        to: SIMD3<Float>(radius + spacing, 0.15, 0),
        color: NSColor.secondary,
        thickness: 0.2
    )
    container.addChild(xaxis)
    
    let xtip = createTip(
        position: SIMD3<Float>(radius + spacing, 0.15, 0),
        direction: SIMD3<Float>(1, 0, 0),
        color: NSColor.secondary,
        height: 1.5,
        radius: 0.5
    )
    container.addChild(xtip)
    let xlabel = createText("X", position: SIMD3<Float>(radius + spacing + 2.5, 0.15, 0), color: NSColor.secondary, size: 2.0)
    container.addChild(xlabel)
    
    let yaxis = createLine(
        from: SIMD3<Float>(0, -radius - spacing, 0),
        to: SIMD3<Float>(0, radius + spacing, 0),
        color: NSColor.secondary,
        thickness: 0.2
    )
    container.addChild(yaxis)
    
    let ytip = createTip(
        position: SIMD3<Float>(0, radius + spacing, 0),
        direction: SIMD3<Float>(0, 1, 0),
        color: NSColor.secondary,
        height: 1.5,
        radius: 0.5
    )
    container.addChild(ytip)
    let ylabel = createText("Y", position: SIMD3<Float>(0, radius + spacing + 1.0, 0), color: NSColor.secondary, size: 2.0)
    container.addChild(ylabel)
    
    let zaxis = createLine(
        from: SIMD3<Float>(0, 0.15, -radius - spacing),
        to: SIMD3<Float>(0, 0.15, radius + spacing),
        color: NSColor.secondary,
        thickness: 0.2
    )
    container.addChild(zaxis)
    
    let ztip = createTip(
        position: SIMD3<Float>(0, 0.15, radius + spacing),
        direction: SIMD3<Float>(0, 0, 1),
        color: NSColor.secondary,
        height: 1.5,
        radius: 0.5
    )
    container.addChild(ztip)
    let zlabel = createText("Z", position: SIMD3<Float>(0, 0.15, radius + spacing + 2.5), color: NSColor.secondary, size: 2.0)
    container.addChild(zlabel)
    
    for i in 0...cells {
        let y = Float(i) * spacing - radius
        if abs(y.truncatingRemainder(dividingBy: tickSpacing)) < 0.001 {
            let tick = createLine(
                from: SIMD3<Float>(-0.5, y, 0),
                to: SIMD3<Float>(0.5, y, 0),
                color: NSColor.secondary,
                thickness: 0.05
            )
            container.addChild(tick)
            if y != 0 {
                let label = createText(String(format: "%.0f", y), position: SIMD3<Float>(1.5, y, 0), color: NSColor.tertiary, size: 1.5)
                container.addChild(label)
            }
        }
    }
    
    return container
}
