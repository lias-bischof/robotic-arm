import Foundation
import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let kind: Kind
    let receipt: String?

    enum Kind {
        case input, output, error, system
    }
    
    func color() -> Color {
        switch kind {
        case .input:  return .white
        case .output: return .white.opacity(0.6)
        case .error:  return .red
        case .system: return .orange
        }
    }
}
