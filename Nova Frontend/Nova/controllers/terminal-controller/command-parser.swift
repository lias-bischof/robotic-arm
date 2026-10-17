import Foundation

struct Parser {

    func parse(_ input: String) -> Command? {
        let parts = input.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let name = parts.first else {
            return nil
        }
        return parse(name: name.lowercased(), args: Array(parts.dropFirst()))
    }

    private func parse(name: String, args: [String]) -> Command {
        switch name {
        case "add":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                let (action, index) = parseOptions(Array(args.dropFirst(3)))
                return .addTarget(x: x, y: y, z: z, action: action, index: index)
            }
            return .unknown("usage: add <x> <y> <z> [none|open|close] [position]")
        case "remove", "rm":
            guard args.count >= 1, let index = Int(args[0]) else {
                return .unknown("usage: remove <index>")
            }
            return .removeTarget(index: index - 1)

        case "set":
            guard args.count >= 2, let index = Int(args[0]) else {
                return .unknown("usage: set <index> <x> <y> <z> | set <index> <\(Action.names())>")
            }
            if args.count >= 4,
               let x = Float(args[1]),
               let y = Float(args[2]),
               let z = Float(args[3]) {
                return .changePosition(index: index - 1, x: x, y: y, z: z)
            }
            if let action = Action.from(args[1]) {
                return .changeAction(index: index - 1, action: action)
            }
            return .unknown("usage: set <index> <x> <y> <z> | set <index> <\(Action.names())>")

        case "move", "mv":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                return .move(x: x, y: y, z: z)
            }
            return .unknown("usage: move <x> <y> <z>")

        case "swap":
            guard args.count >= 2,
                  let i = Int(args[0]),
                  let j = Int(args[1]) else {
                return .unknown("usage: swap <index> <index>")
            }
            return .changeIndices(i: i - 1, j: j - 1)

        case "rotate", "rot":
            if args.count >= 3,
               let basis = Float(args[0]),
               let shoulder = Float(args[1]),
               let arm = Float(args[2]) {
                return .rotateAll(basis: basis, shoulder: shoulder, arm: arm)
            }
            guard args.count >= 2,
                  let degrees = Float(args[1]),
                  ["basis", "shoulder", "arm"].contains(args[0].lowercased()) else {
                return .unknown("usage: rotate <basis|shoulder|arm> <degrees> | rotate <basis> <shoulder> <arm>")
            }
            return .rotate(joint: args[0].lowercased(), degrees: degrees)

        case "orientation", "ori": return .getOrientation
        case "position", "pos": return .getPosition
        case "connect":
            if args.count >= 2 {
                guard let port = Int(args[1]), (1...65535).contains(port) else {
                    return .unknown("usage: connect [host] [port]")
                }
                return .connect(host: args[0], port: port)
            }
            return .connect(host: args.first, port: nil)
        case "disconnect": return .disconnect
        case "start": return .start
        case "stop": return .stop
        case "reset": return .resetCursor
        case "clear": return .clearTargets
        case "help": return .help
        default: return .unknown("unknown command: \(name)")
        }
    }

    private func parseOptions(_ options: [String]) -> (action: Action, index: Int?) {
        var action = Action.NONE
        var index: Int? = nil
        for option in options {
            if let parsed = Action.from(option.lowercased()) {
                action = parsed
            } else if let parsed = Int(option) {
                index = parsed - 1
            }
        }
        return (action, index)
    }
}
