import AppKit
import RealityKit

func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: NSColor, thickness: Float, lit: Bool = false) -> Entity {
    let direction = end - start
    let length = simd_length(direction)
    guard length > 0 else { return Entity() }

    let mesh = MeshResource.generateBox(size: SIMD3<Float>(thickness, thickness, length))
    let entity = ModelEntity(mesh: mesh, materials: [materialOf(color: color, lit: lit)])

    entity.position = (start + end) / 2

    let forward = SIMD3<Float>(0, 0, 1)
    let normalized = simd_normalize(direction)
    let dot = simd_dot(forward, normalized)

    if abs(dot + 1) < 0.0001 {
        entity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    } else if abs(dot - 1) > 0.0001 {
        let axis = simd_normalize(simd_cross(forward, normalized))
        let angle = acos(dot)
        entity.orientation = simd_quatf(angle: angle, axis: axis)
    }

    return entity
}
