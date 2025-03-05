import SwiftUI

struct EmojiSelector: View {
    @EnvironmentObject private var viewModel: MapViewModel
    
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.categories, id: \.1) {
                    emoji,
                    category,
                    _ in
                    Button(
                        action: {
                            withAnimation(
                                .spring(response: 0.3, dampingFraction: 0.7)
                            ) {
                                viewModel.toggleCategory(category)
                                feedback.impactOccurred()
                            }
                        }) {
                            EmojiButton(
                                emoji: emoji,
                                isSelected: viewModel.selectedCategories
                                    .contains(category)
                            )
                        }
                        .buttonStyle(EmojiButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 8)
    }
}

// MARK: - Emoji Button Component
struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 28))
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .fill(
                        isSelected ? Color.blue
                            .opacity(0.15) : Color.gray
                            .opacity(0.08)
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05),
                            radius: isSelected ? 4 : 2,
                            x: 0,
                            y: isSelected ? 2 : 1)
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1.5)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

// MARK: - Custom Button Style
struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .easeInOut(duration: 0.2),
                value: configuration.isPressed
            )
    }
}

struct EmojiSelector_Previews: PreviewProvider {
    static var previews: some View {
        EmojiSelector()
            .environmentObject(
                MapViewModel(googlePlacesService: MockGooglePlacesService())
            )
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
