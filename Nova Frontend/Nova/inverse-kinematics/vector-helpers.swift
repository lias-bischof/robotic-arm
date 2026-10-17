import Foundation

func xyproj(_ vector: SIMD3<Float>) -> SIMD2<Float> {
    return SIMD2<Float>(
        x: vector.x,
        y: vector.y
    )
}
 
func uvproj(azimuth: Float, vector: SIMD3<Float>) -> SIMD3<Float> {
    let x = vector.x * cos(-azimuth) - vector.z * sin(-azimuth)
    let y = vector.y
    let z = vector.x * sin(-azimuth) + vector.z * cos(-azimuth)
    
    return SIMD3<Float>(x, y, z)
}

func uvlift(azimuth: Float, vector: SIMD2<Float>) -> SIMD3<Float> {
    let x = vector.x * cos(azimuth)
    let y = vector.y
    let z = vector.x * sin(azimuth)
    return SIMD3<Float>(x, y, z)
}

private func angle(_ v1: SIMD2<Float>, _ v2: SIMD2<Float>) -> Float {
    let dot = v1.x * v2.x + v1.y * v2.y
    let det = v1.x * v2.y - v1.y * v2.x
    return atan2(det, dot)
}

func elevation(_ vector: SIMD2<Float>) -> Float {
    return atan2(vector.y, vector.x)
}
