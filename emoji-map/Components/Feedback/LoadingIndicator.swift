import SwiftUI

struct LoadingIndicator: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .transition(.opacity.combined(with: .scale))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
        
        LoadingIndicator(message: "Loading places...")
    }
} 