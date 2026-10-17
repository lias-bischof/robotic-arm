import AppKit
import RealityKit

func createSphere(position: SIMD3<Float>, radius: Float, color: NSColor, lit: Bool = false) -> Entity {
    guard radius > 0 else { return Entity() }

    let mesh = MeshResource.generateSphere(radius: radius)
    let entity = ModelEntity(mesh: mesh, materials: [materialOf(color: color, lit: lit)])

    entity.position = position

    return entity
}
