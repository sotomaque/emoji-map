import SwiftUI

/// A loading indicator view with a message
struct LoadingIndicator: View {
    var message: String
    var color: Color = .blue
    var useMetal: Bool = true
    
    var body: some View {
        if useMetal {
            // Use Metal-based loading animation
            MetalLoadingView(color: color, message: message)
                .frame(width: 200, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .onAppear {
                    // Provide haptic feedback when loading starts
                    HapticsManager.shared.mediumImpact()
                }
        } else {
            // Fallback to standard SwiftUI loading indicator
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: color))
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .onAppear {
                // Provide haptic feedback when loading starts
                HapticsManager.shared.mediumImpact()
            }
        }
    }
}

// MARK: - Preview
struct LoadingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
            
            LoadingIndicator(message: "Loading places...")
        }
    }
} 
