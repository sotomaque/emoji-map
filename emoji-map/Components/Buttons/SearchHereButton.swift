import SwiftUI

struct SearchHereButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Search this area")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.accentColor)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .foregroundColor(.white)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            // Provide haptic feedback when button appears
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

#Preview {
    SearchHereButton(action: {})
        .padding()
        .previewLayout(.sizeThatFits)
} 