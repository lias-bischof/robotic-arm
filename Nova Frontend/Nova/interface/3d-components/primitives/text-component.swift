import Foundation
import RealityKit
import AppKit

func createText(_ string: String, position: SIMD3<Float>, color: NSColor, size: Float = 0.05) -> Entity {
    let mesh = MeshResource.generateText(
        string,
        extrusionDepth: 0.001,
        font: .systemFont(ofSize: CGFloat(size)),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )

    var material = UnlitMaterial()
    material.color = .init(tint: color)

    let entity = ModelEntity(mesh: mesh, materials: [material])
    entity.position = position
    entity.components.set(BillboardComponent())

    return entity
}
