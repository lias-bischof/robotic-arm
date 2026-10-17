import RealityKit
import Foundation
import SwiftUI

func materialOf(color: NSColor, lit: Bool = false) -> any RealityKit.Material {
    if lit {
        return SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)
    }
    var material = UnlitMaterial()
    material.color = .init(tint: color)
    return material
}
