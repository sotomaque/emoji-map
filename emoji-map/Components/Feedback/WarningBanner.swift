import SwiftUI

struct WarningBanner: View {
    let message: String
    let isVisible: Bool
    var backgroundColor: Color = .orange
    
    var body: some View {
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
            }
        }
        .transition(.move(edge: .top))
        .animation(.easeInOut, value: isVisible)
    }
}

#Preview {
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
} 