import AppKit
import RealityKit

func createTip(position: SIMD3<Float>, direction: SIMD3<Float>, color: NSColor, height: Float, radius: Float) -> Entity {
    var material = UnlitMaterial()
    material.color = .init(tint: color)

    let mesh = MeshResource.generateCone(height: height, radius: radius)
    let entity = ModelEntity(mesh: mesh, materials: [material])

    entity.position = position

    let up = SIMD3<Float>(0, 1, 0)
    let normalized = simd_normalize(direction)
    let dot = simd_dot(up, normalized)

    if abs(dot + 1) < 0.0001 {
        entity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 0, 1))
    } else if abs(dot - 1) > 0.0001 {
        let axis = simd_normalize(simd_cross(up, normalized))
        let angle = acos(dot)
        entity.orientation = simd_quatf(angle: angle, axis: axis)
    }

    return entity
}
