import simd

func isReachable(_ target: SIMD3<Float>, basis: Joint, shoulder: Joint, arm: Joint) -> Bool {
    let θ0 = atan2(target.z, target.x)
    let pivot = SIMD3<Float>(
        x: basis.length * cos(basis.elevation) * cos(θ0),
        y: basis.length * sin(basis.elevation),
        z: basis.length * cos(basis.elevation) * sin(θ0)
    )
    let distance = simd_length(target - pivot)
    return distance <= shoulder.length + arm.length && distance >= abs(shoulder.length - arm.length)
}

func solve(_ target: SIMD3<Float>, basis: Joint, shoulder: Joint, arm: Joint) throws -> (calibration: [Float], configuration: [Float]) {
    let θ0 = atan2(target.z - basis.foot.z, target.x - basis.foot.x)
    let pivot = SIMD3<Float>(
        x: basis.length * cos(basis.elevation) * cos(θ0),
        y: basis.length * sin(basis.elevation),
        z: basis.length * cos(basis.elevation) * sin(θ0)
    )
    
    let distance = simd.length(target - pivot)
    if distance > shoulder.length + arm.length || distance < abs(shoulder.length - arm.length) {
        throw IKError.unreachable
    }

    let uvpivot = SIMD2<Float>(
        simd_length(SIMD2<Float>(pivot.x, pivot.z)),
        pivot.y
    )
    
    let uvtarget = xyproj(
        uvproj(azimuth: θ0, vector: target - basis.foot)
    )
    
    let uvcontacts = contacts(
        Circle(center: uvpivot,  radius: shoulder.length),
        Circle(center: uvtarget, radius: arm.length)
    )

    var best: (calibration: [Float]?, configuration: [Float]?, cost: Float) = (nil, nil, Float.infinity)
    for uvcontact in uvcontacts {
        let θ1 = elevation(uvcontact - uvpivot)
        let θ2 = elevation(uvtarget - uvcontact)
        let cost = abs(θ1 - shoulder.elevation) + abs(θ2 - arm.elevation)
        if cost < best.cost {
            best = ([θ1 - shoulder.elevation, θ2 - arm.elevation], [θ1, θ2], cost)
        }
    }
    
    guard let calibration = best.calibration, let configuration = best.configuration else {
        throw IKError.contactless
    }

    return (
        calibration: [θ0 - basis.azimuth, calibration[0], calibration[1]],
        configuration: [θ0, configuration[0], configuration[1]]
    )
}
