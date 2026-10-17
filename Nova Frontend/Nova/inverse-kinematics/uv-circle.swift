import simd

struct Circle: Codable {
    let center: SIMD2<Float>
    let radius: Float
}

func contacts(_ c1: Circle, _ c2: Circle) -> [SIMD2<Float>] {
    let d = simd_distance(c1.center, c2.center)
    
    if d > c1.radius + c2.radius {
        return []
    }
    if d < abs(c1.radius - c2.radius) {
        return []
    }
    if d == 0 && c1.radius == c2.radius {
        return []
    }
    let a = (c1.radius * c1.radius - c2.radius * c2.radius + d * d) / (2 * d)
    let h = sqrt(c1.radius * c1.radius - a * a)
    
    let direction = (c2.center - c1.center) / d
    let p = c1.center + direction * a
    
    let offset = SIMD2<Float>(-direction.y, direction.x) * h
    
    if h != 0 {
        return [p + offset, p - offset]
    }
    return [p]
}
