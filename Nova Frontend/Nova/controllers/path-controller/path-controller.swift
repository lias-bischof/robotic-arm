import Foundation
import RealityKit
import SwiftUI

@Observable
class Path {

    var targets: [Target] = []
    var cursor: Int = 0
    var running: Bool = false

    private var task: Task<Void, Never>? = nil
    let scene = Entity()
    
    private let store = Persistent<[Target]>(id: "path")
    
    func save() throws {
        try store.save(targets)
    }

    var closed: Int {
        min(cursor, targets.count)
    }

    var head: Target? {
        guard targets.indices.contains(cursor) else {
            return nil
        }
        return targets[cursor]
    }

    init() {
        let loaded = store.load([])
        for (index, target) in loaded.enumerated() {
            targets.append(target)
            scene.addChild(renderEntity(target: target, index: index))
        }
    }

    func isVisited(_ index: Int) -> Bool { index < closed }
    func isQueued(_ index: Int) -> Bool { index > cursor || (!running && index == cursor) }

    func next() {
        guard cursor < targets.count else { return }
        findEntity(for: targets[cursor])?.removeFromParent()
        cursor += 1
    }

    func previous() {
        guard cursor > 0 else { return }
        cursor -= 1
        renderEntity(at: cursor)
    }

    func reset() {
        let visited = closed
        cursor = 0
        for index in 0..<visited {
            renderEntity(at: index)
        }
    }

    func start(robot: RobotController, logger: LoggerController) {
        running = true
        task = Task {
            var halted = false
            while !Task.isCancelled, let target = head {
                let index = cursor
                do {
                    try await robot.calibrate(target.position)
                    try await robot.perform(target.action)
                } catch {
                    if !Task.isCancelled {
                        logger.log(Path.parseError(error, index: index), kind: .error)
                        halted = true
                    }
                    break
                }
                guard !Task.isCancelled else {
                    break
                }
                logger.log("reached target \(index + 1) at \(formatPoint(target.position))", kind: .output)
                if target.action != .NONE {
                    logger.log("target \(index + 1) action \(target.action.name()) executed", kind: .output)
                }
                next()
            }
            running = false
            if !halted, !Task.isCancelled, cursor >= targets.count {
                logger.log("operation complete — \(targets.count) target(s) visited", kind: .output)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        running = false
    }

    private static func parseError(_ error: Error, index: Int) -> String {
        let reason: String
        switch error {
            case RobotError.busy: reason = "robot is busy"
            case RobotError.offline: reason = "robot is offline"
            case IKError.unreachable: reason = "target is out of reach"
            case MQTTError.offline: reason = "not connected to a broker"
            case MQTTError.publishFailed: reason = "failed to publish target to the robot"
            case MQTTError.commandRejected(let refusal): reason = "robot refused the command: \(refusal)"
            case MQTTError.timedOut: reason = "robot did not respond in time"
            case is CocoaError: reason = "joint state failed to persist to disk"
            default: reason = error.localizedDescription
        }
        return "error: \(reason)"
    }

    func addTarget(position: SIMD3<Float>, action: Action = .NONE) throws {
        let target = Target(position: position, action: action)
        targets.append(target)
        scene.addChild(renderEntity(target: target, index: targets.count - 1))
        try save()
    }

    func addTarget(position: SIMD3<Float>, action: Action = .NONE, at index: Int) throws {
        let clamped = max(0, min(index, targets.count))
        let target = Target(position: position, action: action)
        targets.insert(target, at: clamped)
        scene.addChild(renderEntity(target: target, index: clamped))
        renderAll(from: clamped)
        if clamped < cursor {
            cursor += 1
        }
        try save()
    }
    
    func changeOrder(_ i: Int, _ j: Int) throws {
        guard targets.indices.contains(i), targets.indices.contains(j),
              !isVisited(i), !isVisited(j) else { return }
        targets.swapAt(i, j)
        renderAll(from: min(i, j))
        try save()
    }

    func clearTargets() throws {
        scene.children.removeAll()
        targets.removeAll()
        cursor = 0
        running = false
        try save()
    }

    func removeTarget(at index: Int) throws {
        guard targets.indices.contains(index), !isVisited(index) else { return }
        findEntity(for: targets[index])?.removeFromParent()
        targets.remove(at: index)
        renderAll(from: index)
        cursor = min(cursor, targets.count)
        try save()
    }

    func updateTarget(at index: Int, position: SIMD3<Float>, action: Action) throws {
        guard targets.indices.contains(index) else { return }
        if isVisited(index) { cursor = max(0, cursor - 1) }
        targets[index].position = position
        targets[index].action = action
        guard let entity = findEntity(for: targets[index]) else { return }
        entity.children.removeAll()
        entity.addChild(createLine(from: .zero, to: position, color: .red, thickness: 0.3))
        entity.addChild(createTip(position: position, direction: position, color: .red, height: 1.25, radius: 0.5))
        entity.addChild(createText(String(index + 1), position: position + SIMD3<Float>(0, 1.0, 0), color: .white, size: 1.75))
        try save()
    }

    private func findEntity(for target: Target) -> Entity? {
        scene.children.first { $0.name == target.id.uuidString }
    }

    private func renderAll(from start: Int) {
        for i in start..<targets.count {
            guard let entity = findEntity(for: targets[i]) else { continue }
            guard !entity.children.isEmpty else { continue }
            entity.children.remove(at: entity.children.count - 1)
            entity.addChild(createText(
                String(i + 1),
                position: targets[i].position + SIMD3<Float>(0, 1.0, 0),
                color: .white,
                size: 1.75
            ))
        }
    }

    func renderEntity(target: Target, index: Int) -> Entity {
        let container = Entity()
        container.name = target.id.uuidString
        container.addChild(createLine(from: .zero, to: target.position, color: .red, thickness: 0.3))
        container.addChild(createTip(position: target.position, direction: target.position, color: .red, height: 1.25, radius: 0.5))
        container.addChild(createText(String(index + 1), position: target.position + SIMD3<Float>(0, 1.0, 0), color: .white, size: 1.75))
        return container
    }
    
    private func renderEntity(at index: Int) {
        if findEntity(for: targets[index]) != nil {
            let entity = renderEntity(target: targets[index], index: index)
            scene.addChild(entity)
        }
    }
}
