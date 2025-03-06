import SwiftUI

struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}


// MARK: Preview
struct EmojiButtonStylePreview: PreviewProvider {
    static var previews: some View {
        Button("Test Button") {}
            .buttonStyle(EmojiButtonStyle())
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
