import Foundation
import simd
import Observation
import RealityKit
import AppKit

@Observable
class MachineController {
    
    var basis: Joint
    var shoulder: Joint
    var arm: Joint
    var scene = Entity()

    init() {
        let basis = Joint.load(BASIS_FALLBACK)
        let shoulder = Joint.load(SHOULDER_FALLBACK)
        shoulder.move(foot: basis.head())
        let arm = Joint.load(ARM_FALLBACK)
        arm.move(foot: shoulder.head())
        self.basis = basis
        self.shoulder = shoulder
        self.arm = arm
        self.render()
    }

    func rotate(basis degrees: Float) -> (calibration: [Float], configuration: [Float]) {
        return calibrate(angles: [basis.azimuth + toRadians(degrees), shoulder.elevation, arm.elevation])
    }

    func rotate(shoulder degrees: Float) -> (calibration: [Float], configuration: [Float]) {
        return calibrate(angles: [basis.azimuth, shoulder.elevation + toRadians(degrees), arm.elevation])
    }

    func rotate(arm degrees: Float) -> (calibration: [Float], configuration: [Float]) {
        return calibrate(angles: [basis.azimuth, shoulder.elevation, arm.elevation + toRadians(degrees)])
    }

    func rotateAll(basis: Float, shoulder: Float, arm: Float) -> (calibration: [Float], configuration: [Float]) {
        return calibrate(angles: [
            self.basis.azimuth + toRadians(basis),
            self.shoulder.elevation + toRadians(shoulder),
            self.arm.elevation + toRadians(arm)
        ])
    }

    func calibrate(target: SIMD3<Float>) throws -> (calibration: [Float], configuration: [Float]) {
        let result = try solve(target, basis: basis, shoulder: shoulder, arm: arm)
        apply(result.configuration)
        return result
    }

    func calibrate(angles: [Float]) -> (calibration: [Float], configuration: [Float]) {
        let calibration = [
            angles[0] - basis.azimuth,
            angles[1] - shoulder.elevation,
            angles[2] - arm.elevation
        ]
        apply(angles)
        return (calibration: calibration, configuration: angles)
    }

    private func apply(_ angles: [Float]) {
        basis.rotate(azimuth: angles[0])
        shoulder.foot = basis.head()
        shoulder.rotate(azimuth: angles[0])
        shoulder.rotate(elevation: angles[1])
        arm.foot = shoulder.head()
        arm.rotate(azimuth: angles[0])
        arm.rotate(elevation: angles[2])
    }

    func save() throws {
        try basis.save()
        try shoulder.save()
        try arm.save()
    }
    
    func render() {
        scene.children.removeAll()
        for joint in [basis, shoulder, arm] {
            scene.addChild(createLine(
                from: joint.foot,
                to: joint.head(),
                color: .orange,
                thickness: 0.75,
                lit: true
            ))
            scene.addChild(createSphere(
                position: joint.head(),
                radius: 0.75,
                color: .orange,
                lit: true
            ))
        }
    }
}
