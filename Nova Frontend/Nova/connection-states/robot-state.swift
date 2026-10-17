import Foundation
import SwiftUI

enum RobotState: Equatable {
    case READY
    case BUSY
    case OFFLINE
    case CONNECTING

    static func == (lhs: RobotState, rhs: RobotState) -> Bool {
        switch (lhs, rhs) {
        case (.READY, .READY): return true
        case (.BUSY, .BUSY): return true
        case (.OFFLINE, .OFFLINE): return true
        case (.CONNECTING, .CONNECTING): return true
        default: return false
        }
    }
    
    func color() -> Color {
        switch self {
        case .READY: return .green
        case .BUSY: return .yellow
        case .CONNECTING: return .yellow
        case .OFFLINE: return .gray
        }
    }

    func label() -> String {
        switch self {
        case .READY: return "ROBOT READY"
        case .BUSY: return "ROBOT BUSY"
        case .CONNECTING: return "ROBOT CONNECTING"
        case .OFFLINE: return "ROBOT OFFLINE"
        }
    }

    func pending() -> Bool {
        switch self {
        case .BUSY, .CONNECTING: return true
        case .READY, .OFFLINE: return false
        }
    }
}
