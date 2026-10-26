import Foundation
import simd

final class TerminalController {

    private let parser = Parser()
    private let logger: LoggerController
    private let path: Path
    private let robot: RobotController
    private let mqtt: MQTTController

    init(path: Path, robot: RobotController, mqtt: MQTTController, logger: LoggerController) {
        self.path = path
        self.robot = robot
        self.mqtt = mqtt
        self.logger = logger
    }

    func handle(_ input: String) {
        guard let command = parser.parse(input) else {
            return
        }
        execute(command)
    }

    func execute(_ command: Command) {
        switch command {
        case .addTarget(let x, let y, let z, let action, let index):
            let position = SIMD3(x, y, z)
            let machine = robot.machine
            guard isReachable(position, basis: machine.basis, shoulder: machine.shoulder, arm: machine.arm) else {
                logger.log("error: target (\(x), \(y), \(z)) is out of reach", kind: .error)
                return
            }
            addTarget(position: position, action: action, at: index, label: "(\(x), \(y), \(z))")

        case .removeTarget(let index):
            guard path.targets.indices.contains(index) else {
                logger.log("error: target \(index + 1) does not exist", kind: .error);
                return
            }
            guard path.isQueued(index) else {
                logger.log("error: target \(index + 1) has already been visited", kind: .error);
                return
            }
            do {
                try path.removeTarget(at: index)
                logger.log("removed target \(index + 1)", kind: .output)
            } catch {
                logger.log("error: failed to save operation to disk", kind: .error)
            }
        case .changePosition(let index, let x, let y, let z):
            guard path.targets.indices.contains(index) else {
                logger.log("error: target \(index + 1) does not exist", kind: .error);
                return
            }
            guard path.isQueued(index) else {
                logger.log("error: target \(index + 1) has already been visited", kind: .error);
                return
            }
            let position = SIMD3(x, y, z)
            let machine = robot.machine
            guard isReachable(position, basis: machine.basis, shoulder: machine.shoulder, arm: machine.arm) else {
                logger.log("error: target (\(x), \(y), \(z)) is out of reach", kind: .error)
                return
            }
            do {
                let action = path.targets[index].action
                try path.updateTarget(at: index, position: position, action: action)
                logger.log("set target \(index + 1) to (\(x), \(y), \(z))", kind: .output)
            } catch {
                logger.log("error: failed to save operation to disk", kind: .error)
            }

        case .move(let x, let y, let z):
            move(to: SIMD3(x, y, z), label: "(\(x), \(y), \(z))")

        case .changeAction(let index, let action):
            guard path.targets.indices.contains(index) else {
                logger.log("error: target \(index + 1) does not exist", kind: .error);
                return
            }
            guard path.isQueued(index) else {
                logger.log("error: target \(index + 1) has already been visited", kind: .error);
                return
            }
            do {
                try path.updateTarget(at: index, position: path.targets[index].position, action: action)
                logger.log("target \(index + 1) action set to \(action.name())", kind: .output)
            } catch {
                logger.log("error: failed to save operation to disk", kind: .error)
            }

        case .changeIndices(let i, let j):
            guard path.targets.indices.contains(i), path.targets.indices.contains(j) else {
                logger.log("error: one or both indices are out of range", kind: .error);
                return
            }
            guard path.isQueued(i), path.isQueued(j) else {
                logger.log("error: only queued targets can be swapped", kind: .error);
                return
            }
            do {
                try path.changeOrder(i, j)
                logger.log("swapped targets \(i + 1) and \(j + 1)", kind: .output)
            } catch {
                logger.log("error: failed to save operation to disk", kind: .error)
            }

        case .rotate(let joint, let degrees):
            let machine = robot.machine
            switch joint {
            case "basis":
                rotate(label: joint) {
                    machine.rotate(basis: degrees)
                } success: {
                    "rotated basis to \(formatAngle(machine.basis.azimuth))°"
                }
            case "shoulder":
                rotate(label: joint) {
                    machine.rotate(shoulder: degrees)
                } success: {
                    "rotated shoulder to \(formatAngle(machine.shoulder.elevation))°"
                }
            case "arm":
                rotate(label: joint) {
                    machine.rotate(arm: degrees)
                } success: {
                    "rotated arm to \(formatAngle(machine.arm.elevation))°"
                }
            default: break
            }

        case .rotateAll(let basis, let shoulder, let arm):
            let machine = robot.machine
            rotate(label: "joints") {
                machine.rotateAll(basis: basis, shoulder: shoulder, arm: arm)
            } success: {
                "rotated basis to \(formatAngle(machine.basis.azimuth))°, shoulder to \(formatAngle(machine.shoulder.elevation))°, arm to \(formatAngle(machine.arm.elevation))°"
            }

        case .getOrientation:
            let machine = robot.machine
            logger.log("basis \(formatAngle(machine.basis.azimuth))°", kind: .output)
            logger.log("shoulder \(formatAngle(machine.shoulder.elevation))°", kind: .output)
            logger.log("arm \(formatAngle(machine.arm.elevation))°", kind: .output)

        case .getPosition:
            let machine = robot.machine
            logger.log("basis \(formatPoint(machine.basis.head()))", kind: .output)
            logger.log("shoulder \(formatPoint(machine.shoulder.head()))", kind: .output)
            logger.log("tool \(formatPoint(machine.arm.head()))", kind: .output)

        case .connect(let host, let port):
            guard mqtt.mqttState != .CONNECTED && mqtt.mqttState != .CONNECTING else {
                logger.log("error: already connected to \(mqtt.host):\(mqtt.port)", kind: .error)
                return
            }
            let target = "\(host ?? mqtt.host):\(port ?? mqtt.port)"
            logger.log("connecting to \(target)...", kind: .output)
            Task {
                do {
                    try await mqtt.connect(host: host, port: port)
                    logger.log("connected to broker at \(target)", kind: .output)
                } catch MQTTError.connectionFailed(let error) {
                    logger.log("error: could not connect to \(target) — \(error)", kind: .error)
                } catch {
                    logger.log("error: could not connect to \(target) — \(error)", kind: .error)
                }
            }

        case .disconnect:
            guard mqtt.mqttState != .DISCONNECTED else {
                logger.log("error: not connected to any broker", kind: .error)
                return
            }
            logger.log("disconnecting...", kind: .output)
            Task {
                await mqtt.disconnect()
                logger.log("disconnected from broker", kind: .output)
            }

        case .start:
            guard !path.running else {
                logger.log("error: the operation is already running", kind: .error)
                return
            }
            guard !path.targets.isEmpty else {
                logger.log("error: no targets defined", kind: .error)
                return
            }
            guard path.cursor < path.targets.count else {
                logger.log("error: all targets have been visited", kind: .error)
                return
            }
            logger.log("operation started with \(path.targets.count - path.cursor) target(s) queued", kind: .output)
            path.start(robot: robot, logger: logger)

        case .stop:
            guard path.running else {
                logger.log("error: no operation is currently running", kind: .error)
                return
            }
            path.stop()
            logger.log("operation stopped, sending hardware stop...", kind: .output)
            Task {
                do {
                    try await robot.stopHardware()
                    logger.log("hardware stop acknowledged", kind: .output)
                } catch RobotError.offline {
                    logger.log("error: robot is offline", kind: .error)
                } catch MQTTError.offline {
                    logger.log("error: not connected to a broker", kind: .error)
                } catch MQTTError.publishFailed {
                    logger.log("error: failed to publish stop request", kind: .error)
                } catch MQTTError.commandRejected(let reason) {
                    logger.log("error: stop request was rejected: \(reason)", kind: .error)
                } catch MQTTError.timedOut {
                    logger.log("error: stop request timed out", kind: .error)
                } catch {
                    logger.log("error: hardware stop failed — \(error.localizedDescription)", kind: .error)
                }
            }

        case .resetCursor:
            guard !path.running else {
                logger.log("error: cannot reset while the operation is running", kind: .error); return
            }
            path.reset()
            logger.log("operation cursor reset", kind: .output)

        case .clearTargets:
            guard !path.running else {
                logger.log("error: cannot clear while the operation is running", kind: .error); return
            }
            do {
                let count = path.targets.count
                try path.clearTargets()
                logger.log("cleared \(count) target(s)", kind: .output)
            } catch {
                logger.log("error: failed to save operation to disk", kind: .error)
            }

        case .help:
            help()

        case .unknown(let msg):
            logger.log(msg, kind: .error)
        }
    }

    private func addTarget(position: SIMD3<Float>, action: Action, at index: Int?, label: String) {
        do {
            if let index {
                let queued = path.running ? path.cursor + 1 : path.cursor
                guard index >= queued, index <= path.targets.count else {
                    logger.log("error: position \(index + 1) is not in the queue", kind: .error)
                    return
                }
                try path.addTarget(position: position, action: action, at: index)
                logger.log("added target \(index + 1) at \(label)", kind: .output)
            } else {
                try path.addTarget(position: position, action: action)
                logger.log("added target \(path.targets.count) at \(label)", kind: .output)
            }
        } catch {
            logger.log("error: failed to save operation to disk", kind: .error)
        }
    }

    private func rotate(
        label: String,
        _ calibration: @escaping () -> (calibration: [Float], configuration: [Float]),
        success: @escaping () -> String
    ) {
        Task {
            do {
                try await robot.calibrate(calibration: calibration)
                logger.log(success(), kind: .output)
            } catch RobotError.offline {
                logger.log("error: robot is offline", kind: .error)
            } catch RobotError.busy {
                logger.log("error: robot is busy", kind: .error)
            } catch IKError.unreachable {
                logger.log("error: target position is out of reach", kind: .error)
            } catch is CocoaError {
                logger.log("error: joint state failed to persist to disk", kind: .error)
            } catch MQTTError.offline {
                logger.log("error: not connected to a broker", kind: .error)
            } catch MQTTError.publishFailed {
                logger.log("error: failed to publish calibration to the robot", kind: .error)
            } catch MQTTError.commandRejected(let reason) {
                logger.log("error: robot refused the command: \(reason)", kind: .error)
            } catch MQTTError.timedOut {
                logger.log("error: robot did not respond in time", kind: .error)
            } catch {
                logger.log("error: could not rotate \(label) — \(error.localizedDescription)", kind: .error)
            }
        }
    }

    private func move(to position: SIMD3<Float>, label: String) {
        Task {
            do {
                try await robot.calibrate(position)
                logger.log("moved to \(label)", kind: .output)
            } catch RobotError.offline {
                logger.log("error: robot is offline", kind: .error)
            } catch RobotError.busy {
                logger.log("error: robot is busy", kind: .error)
            } catch IKError.unreachable {
                logger.log("error: position is out of reach", kind: .error)
            } catch is CocoaError {
                logger.log("error: joint state failed to persist to disk", kind: .error)
            } catch MQTTError.offline {
                logger.log("error: not connected to a broker", kind: .error)
            } catch MQTTError.publishFailed {
                logger.log("error: failed to publish calibration to the robot", kind: .error)
            } catch MQTTError.commandRejected(let reason) {
                logger.log("error: robot refused the command: \(reason)", kind: .error)
            } catch MQTTError.timedOut {
                logger.log("error: robot did not respond in time", kind: .error)
            } catch {
                logger.log("error: could not move to \(label) — \(error.localizedDescription)", kind: .error)
            }
        }
    }

    func help() {
        let lines = [
            "add <x> <y> <z> [action] [position]  — add target at coordinates",
            "remove <index>                       — remove a queued target",
            "set <index> <x> <y> <z>              — change position of a queued target",
            "set <index> <action>                 — change action of a queued target",
            "swap <index> <index>                 — swap two queued targets",
            "move <x> <y> <z>                     — move robot to coordinates",
            "rotate <joint> <degrees>             — rotate a single joint",
            "rotate <basis> <shoulder> <arm>      — rotate all three joints at once",
            "orientation                          — show current joint angles",
            "position                             — show current joint positions",
            "start / stop                         — start or stop the operation",
            "reset                                — reset operation to first target",
            "clear                                — remove all targets",
            "connect / disconnect                 — mqtt connection"
        ]
        lines.forEach {
            logger.log($0, kind: .system)
        }
    }
}
