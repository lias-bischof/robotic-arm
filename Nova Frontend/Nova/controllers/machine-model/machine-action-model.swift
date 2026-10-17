import SwiftUI

enum Action: String, Codable, CaseIterable {
    case NONE
    case CLOSE
    case OPEN

    func name() -> String {
        switch self {
        case .NONE:  return "none"
        case .CLOSE: return "close"
        case .OPEN:  return "open"
        }
    }

    static func names() -> String {
        return Action.allCases.map { $0.name() }.joined(separator: "|")
    }

    static func from(_ string: String) -> Action? {
        return Action.allCases.first { $0.name() == string }
    }
    
    func icon() -> String {
        switch self {
        case .NONE:  return "circle.dashed"
        case .OPEN:  return "arrow.up.left.and.arrow.down.right"
        case .CLOSE: return "arrow.down.right.and.arrow.up.left"
        }
    }

    func color() -> Color {
        switch self {
        case .NONE:  return .gray
        case .OPEN:  return .cyan
        case .CLOSE: return .orange
        }
    }
}
