import SwiftUI

struct RecenterButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .disabled(isLoading) // Disable during loading
        .opacity(isLoading ? 0.6 : 1.0) // Fade during loading
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
        
        VStack(spacing: 20) {
            RecenterButton(isLoading: false, action: {})
            RecenterButton(isLoading: true, action: {})
        }
    }
} 