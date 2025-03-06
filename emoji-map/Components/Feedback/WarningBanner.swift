import SwiftUI

struct WarningBanner: View {
    let message: String
    let isVisible: Bool
    var backgroundColor: Color = .orange
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isVisible {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(backgroundColor)
                        .cornerRadius(0)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                
                Spacer()
            }
            .frame(width: geometry.size.width) // Use full width
        }
        .transition(.move(edge: .top))
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .ignoresSafeArea(.all, edges: .top) // Ignore safe area at the top
        .zIndex(999) // Very high z-index to ensure it's above other elements
    }
}

// MARK: Preview
struct WarningBannerPreview: PreviewProvider {
    static var previews: some View {
        VStack {
            WarningBanner(
                message: "API key not configured properly",
                isVisible: true
            )
            
            Spacer()
            
            WarningBanner(
                message: "Network connection lost",
                isVisible: true,
                backgroundColor: .red
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
