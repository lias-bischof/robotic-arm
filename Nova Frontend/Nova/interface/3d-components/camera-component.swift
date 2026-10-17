import RealityKit

func createCamera() -> PerspectiveCamera {
    let camera = PerspectiveCamera()
    let distance: Float = 85.0
    let angle: Float = .pi / 3
    
    camera.position = SIMD3<Float>(
        0,
        distance * 0.6,
        distance * sin(angle)
    )
    camera.look(at: SIMD3<Float>(0, 0, 0), from: camera.position, relativeTo: nil)
        
    let light = DirectionalLight()
    camera.addChild(light)
    
    return camera
}
