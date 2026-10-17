import Foundation

func toDegrees(_ radians: Float) -> Float {
    return radians * 180 / .pi
}

func toRadians(_ degrees: Float) -> Float {
    return degrees * .pi / 180
}
