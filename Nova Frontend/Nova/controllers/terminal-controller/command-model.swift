import Foundation
import simd

enum Command {
    case addTarget(x: Float, y: Float, z: Float, action: Action, index: Int?)
    case removeTarget(index: Int)
    case move(x: Float, y: Float, z: Float)
    case changePosition(index: Int, x: Float, y: Float, z: Float)
    case changeIndices(i: Int, j: Int)
    case changeAction(index: Int, action: Action)
    case rotate(joint: String, degrees: Float)
    case rotateAll(basis: Float, shoulder: Float, arm: Float)
    case getOrientation
    case getPosition
    case connect(host: String?, port: Int?)
    case disconnect
    case start
    case stop
    case resetCursor
    case clearTargets
    case help
    case unknown(String)
}
