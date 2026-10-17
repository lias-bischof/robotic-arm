import SwiftUI

struct Card<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.1), in: .rect(cornerRadius: 5))
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .kerning(1)
                        .opacity(0.7)
                        .foregroundStyle(.white)
                        .padding(.leading, 1)
                    Text(description)
                        .font(.system(size: 10, design: .rounded))
                        .kerning(1)
                        .foregroundStyle(.gray)
                        .opacity(0.7)
                        .padding(.leading, 2)
                }
            }
            content()
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial.opacity(0.4), in: .rect(cornerRadius: 7))
    }
}
