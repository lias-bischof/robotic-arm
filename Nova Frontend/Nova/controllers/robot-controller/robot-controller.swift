import Foundation
import RealityKit
import AppKit
import SwiftUI
import MQTTNIO
import NIOCore

@Observable
final class RobotController {

    let machine = MachineController()
    let mqtt: MQTTController
    
    var state: RobotState {
        get { mqtt.robotState }
        set { mqtt.robotState = newValue }
    }

    init(mqtt: MQTTController) {
        self.mqtt = mqtt
    }

    func perform(_ action: Action) async throws {
        guard action != .NONE else { return }
        if state == .BUSY {
            throw RobotError.busy
        }
        if state == .OFFLINE || state == .CONNECTING {
            throw RobotError.offline
        }
        state = .BUSY
        do {
            try await mqtt.sendData(topic: MQTTTopic.gripper, payload: action.name())
        } catch {
            if case MQTTError.timedOut = error {
                state = .OFFLINE
            } else {
                state = mqtt.mqttState == .CONNECTED ? .READY : .OFFLINE
            }
            throw error
        }
        state = .READY
    }

    func stopHardware() async throws {
        if state == .OFFLINE || state == .CONNECTING {
            throw RobotError.offline
        }
        _ = try await mqtt.sendData(
            topic: MQTTTopic.stop,
            payload: "",
            timeout: 10
        )
    }
    
    func calibrate(_ position: SIMD3<Float>) async throws {
        try await calibrate {
            try machine.calibrate(target: position)
        }
    }

    func calibrate(calibration: () throws -> (calibration: [Float], configuration: [Float])) async throws {
        if state == .BUSY {
            throw RobotError.busy
        }
        if state == .OFFLINE || state == .CONNECTING {
            throw RobotError.offline
        }
        let previous = [machine.basis.azimuth, machine.shoulder.elevation, machine.arm.elevation]
        let (calibration, _) = try calibration()
        machine.render()
        state = .BUSY
        do {
            try machine.save()
            try await mqtt.sendData(topic: MQTTTopic.calibration, payload: calibration)
        } catch {
            rollback(to: previous)
            if case MQTTError.timedOut = error {
                state = .OFFLINE
            } else {
                state = mqtt.mqttState == .CONNECTED ? .READY : .OFFLINE
            }
            throw error
        }
        state = .READY
    }

    private func rollback(to configuration: [Float]) {
        _ = machine.calibrate(angles: configuration)
        try? machine.save()
        machine.render()
    }
}
