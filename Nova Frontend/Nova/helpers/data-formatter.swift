import Foundation

func formatAngle(_ radians: Float) -> String {
    String(format: "%.1f", radians * 180 / .pi)
}

func formatPoint(_ point: SIMD3<Float>) -> String {
    String(format: "(%.2f, %.2f, %.2f)", point.x, point.y, point.z)
}
