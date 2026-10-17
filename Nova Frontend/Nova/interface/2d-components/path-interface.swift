import SwiftUI
import Foundation

typealias CPath = SwiftUI.Path

struct PathInterface: View {

    var path: Path
    var machine: MachineController

    var body: some View {

        Card(icon: "location.fill", title: "PATH", description: "WAYPOINTS & PLANNED TRAJECTORY") {
            VStack(alignment: .leading, spacing: 25) {

                let targets = path.targets
                let cursor = path.cursor

                VStack(alignment: .leading, spacing: 8) {
                    Section(icon: "checkmark.circle.fill", title: "VISITED")
                    if cursor > 0 {
                        VStack(spacing: 3) {
                            ForEach(0..<min(cursor, targets.count), id: \.self) { index in
                                targetItem(index: index, target: targets[index])
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Section(icon: "bolt.horizontal.fill", title: "NEXT")
                    if path.running && targets.indices.contains(cursor) {
                        targetItem(index: cursor, target: targets[cursor])
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Section(icon: "clock.fill", title: "QUEUED")
                    let queued = path.running ? cursor + 1 : cursor
                    if queued < targets.count {
                        VStack(spacing: 3) {
                            ForEach(queued..<targets.count, id: \.self) { index in
                                targetItem(index: index, target: targets[index])
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Section(icon: "move.3d", title: "ESTIMATED PATH")

                    Canvas { context, size in

                        let inset: CGFloat = 24
                        let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
                        let mid = CGPoint(x: rect.midX, y: rect.midY)
                        let extent: CGFloat = 30
                        let steps = 5

                        var xaxis = CPath()
                        xaxis.move(to: CGPoint(x: rect.minX, y: mid.y))
                        xaxis.addLine(to: CGPoint(x: rect.maxX, y: mid.y))
                        context.stroke(xaxis, with: .color(.gray.opacity(0.25)), style: .init())

                        var yaxis = CPath()
                        yaxis.move(to: CGPoint(x: mid.x, y: rect.minY))
                        yaxis.addLine(to: CGPoint(x: mid.x, y: rect.maxY))
                        context.stroke(yaxis, with: .color(.gray.opacity(0.25)), style: .init())

                        for i in -steps...steps {
                            let x = mid.x + CGFloat(i) / CGFloat(steps) * (rect.width / 2)
                            var tick = CPath()
                            tick.move(to: CGPoint(x: x, y: mid.y - 4))
                            tick.addLine(to: CGPoint(x: x, y: mid.y + 4))
                            context.stroke(tick, with: .color(.gray.opacity(0.5)), style: .init())
                            if i != 0 {
                                context.draw(
                                    Text("\(i * Int(extent) / steps)").font(.system(size: 7, design: .monospaced)).foregroundStyle(.gray.opacity(0.6)),
                                    at: CGPoint(x: x, y: mid.y + 12)
                                )
                            }
                        }

                        for i in -steps...steps {
                            let y = mid.y + CGFloat(i) / CGFloat(steps) * (rect.height / 2)
                            var tick = CPath()
                            tick.move(to: CGPoint(x: mid.x - 4, y: y))
                            tick.addLine(to: CGPoint(x: mid.x + 4, y: y))
                            context.stroke(tick, with: .color(.gray.opacity(0.5)), style: .init())
                            if i != 0 {
                                context.draw(
                                    Text("\(i * Int(extent) / steps)").font(.system(size: 7, design: .monospaced)).foregroundStyle(.gray.opacity(0.6)),
                                    at: CGPoint(x: mid.x - 14, y: y)
                                )
                            }
                        }

                        context.draw(
                            Text("Z").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.gray),
                            at: CGPoint(x: mid.x, y: rect.minY - 10)
                        )

                        context.draw(
                            Text("X").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.gray),
                            at: CGPoint(x: rect.maxX + 10, y: mid.y)
                        )

                        let robotPosition = machine.arm.head()
                        var initial = [machine.basis.azimuth, machine.shoulder.elevation, machine.arm.elevation]
                        let queued = path.targets.dropFirst(path.cursor)

                        for target in queued {
                            guard let angles = try? solve(
                                target.position,
                                basis: machine.basis,
                                shoulder: machine.shoulder,
                                arm: machine.arm
                            ).configuration else {
                                continue
                            }
                            createPath(&context, machine: machine, initial: initial, target: angles, mid: mid, extent: extent, rect: rect)
                            initial = angles
                        }

                        for target in queued {
                            let tip = createPoint(CGFloat(target.position.x), CGFloat(target.position.z), mid: mid, extent: extent, rect: rect)
                            createVector(&context, from: mid, to: tip, color: .red)
                        }

                        let robotTip = createPoint(
                            CGFloat(robotPosition.x),
                            CGFloat(robotPosition.z),
                            mid: mid,
                            extent: extent,
                            rect: rect
                        )
                        createVector(&context, from: mid, to: robotTip, color: .orange)
                    }
                    .frame(width: 450, height: 450)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private func shortestDistance(_ from: Float, _ to: Float) -> Float {
    var angdif = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
    if angdif > .pi {
        angdif -= 2 * .pi
    } else if angdif < -.pi {
        angdif += 2 * .pi
    }
    return angdif
}

func estimatedPath(_ basis: Joint, _ shoulder: Joint, _ arm: Joint, _ initial: [Float], _ target: [Float], _ step: Float) -> SIMD2<Float> {
    let j = min(max(step, 0), 1)

    let joints = [basis, shoulder, arm]
    let deltas = zip(initial, target).map { shortestDistance($0, $1) }
    let durations = zip(joints, deltas).map { joint, delta -> Float in
        return joint.speed > 0 ? abs(delta) / joint.speed : 0
    }

    func progress(_ i: Int) -> Float {
        guard durations[i] > 0 else { return 1 }
        return min(j * durations.max()! / durations[i], 1)
    }

    let θ0 = initial[0] + deltas[0] * progress(0)
    let θ1 = initial[1] + deltas[1] * progress(1)
    let θ2 = initial[2] + deltas[2] * progress(2)

    let pivot = basis.length * cos(basis.elevation) * SIMD2<Float>(cos(θ0), sin(θ0))
    let radial = shoulder.length * cos(θ1) + arm.length * cos(θ2)
    return pivot + radial * SIMD2<Float>(cos(θ0), sin(θ0))
}

private func createPath(_ context: inout GraphicsContext, machine: MachineController, initial: [Float], target: [Float], mid: CGPoint, extent: CGFloat, rect: CGRect){
    let samples = 40
    var line = CPath()
    for j in 0...samples {
        let step = Float(j) / Float(samples)
        let sample = estimatedPath(machine.basis, machine.shoulder, machine.arm, initial, target, step)
        let point = createPoint(CGFloat(sample.x), CGFloat(sample.y), mid: mid, extent: extent, rect: rect)
        if j == 0 {
            line.move(to: point)
        } else {
            line.addLine(to: point)
        }
    }
    context.stroke(line, with: .color(.cyan))
}

private func targetItem(index: Int, target: Target, duration: Float? = nil) -> some View {
    HStack(spacing: 12) {
        Text(String(format: "%02d", index + 1))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 24, height: 24)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 5))

        Divider()
            .foregroundStyle(.white.opacity(0.5))

        VStack(alignment: .leading, spacing: 3) {
            Text("POSITION")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.gray.opacity(0.6))
                .kerning(0.5)
            Text(String(format: "%.2f, %.2f, %.2f", target.position.x, target.position.y, target.position.z))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }

        Spacer()

        if let duration {
            Text(String(format: "%.1fs", duration))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.white.opacity(0.05), in: .rect(cornerRadius: 4))
        }

        HStack(spacing: 5) {
            Image(systemName: target.action.icon())
                .font(.system(size: 9, weight: .medium))
            Text(target.action.name().uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .kerning(0.5)
        }
        .foregroundStyle(target.action.color().opacity(1))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(target.action.color().opacity(0.12), in: .rect(cornerRadius: 5))
    }
    .frame(height: 40)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.white.opacity(0.04), in: .rect(cornerRadius: 6))
}
