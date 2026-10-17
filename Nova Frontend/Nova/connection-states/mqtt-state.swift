import SwiftUI

enum MQTTState: Equatable {
    case DISCONNECTED
    case CONNECTING
    case CONNECTED

    static func == (lhs: MQTTState, rhs: MQTTState) -> Bool {
        switch (lhs, rhs) {
        case (.DISCONNECTED, .DISCONNECTED): return true
        case (.CONNECTING, .CONNECTING): return true
        case (.CONNECTED, .CONNECTED): return true
        default: return false
        }
    }
    
    func color() -> Color {
        switch self {
        case .CONNECTED: return .green
        case .CONNECTING:   return .yellow
        case .DISCONNECTED: return .gray
        }
    }

    func label() -> String {
        switch self {
        case .CONNECTED: return "BROKER CONNECTED"
        case .CONNECTING: return "BROKER CONNECTING"
        case .DISCONNECTED: return "BROKER OFFLINE"
        }
    }
}
