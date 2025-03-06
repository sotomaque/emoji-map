import SwiftUI

struct SearchHereButton: View {
    var action: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    // Show compact loading indicator when loading
                    UnifiedLoadingIndicator(
                        message: "Searching...",
                        color: .white,
                        style: .compact,
                        backgroundColor: Color.accentColor
                    )
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Search this area")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.accentColor)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(.white)
        }
        .disabled(isLoading)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            // Provide haptic feedback when button appears
            HapticsManager.shared.mediumImpact()
        }
    }
}

// MARK: Preview
struct SearchHereButtonPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SearchHereButton(action: {})
                .previewDisplayName("Normal")
            
            SearchHereButton(action: {}, isLoading: true)
                .previewDisplayName("Loading")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
