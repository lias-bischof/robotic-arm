import SwiftUI

struct Section: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.5))
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
        }
    }
}
