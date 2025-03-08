import SwiftUI

struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            // Add a slight rotation for more dynamic feel
            .rotationEffect(configuration.isPressed ? Angle(degrees: -2) : Angle(degrees: 0))
            // Add a slight vertical offset when pressed
            .offset(y: configuration.isPressed ? 1 : 0)
            // Use a more responsive spring animation
            .animation(
                .spring(response: 0.15, dampingFraction: 0.6, blendDuration: 0.1),
                value: configuration.isPressed
            )
    }
}


// MARK: Preview
struct EmojiButtonStylePreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button(action: {}) {
                Text("🍕")
                    .font(.system(size: 24))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.blue.opacity(0.15)))
            }
            .buttonStyle(EmojiButtonStyle())
            
            Button(action: {}) {
                Text("All")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.blue))
            }
            .buttonStyle(EmojiButtonStyle())
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
