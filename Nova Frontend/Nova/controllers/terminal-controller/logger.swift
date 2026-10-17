import Foundation
import SwiftUI
import simd

@Observable
final class LoggerController {

    var messages: [Message] = []
    
    func log(_ text: String, kind: Message.Kind = .output, receipt: String? = nil) {
        messages.append(Message(text: text, kind: kind, receipt: receipt))
    }

    private func f(_ v: Float) -> String {
        String(format: "%.2f", v)
    }
}
