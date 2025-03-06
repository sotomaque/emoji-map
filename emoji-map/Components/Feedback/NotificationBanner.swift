import SwiftUI

struct NotificationBanner: View {
    let message: String
    let isVisible: Bool
    var onAppear: (() -> Void)? = nil
    
    var body: some View {
        VStack {
            Spacer()
            
            if isVisible {
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                            .shadow(
                                color: .black.opacity(0.2),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        onAppear?()
                    }
            }
        }
        .animation(.spring(response: 0.4), value: isVisible)
        .zIndex(100) // Ensure it's above other elements
    }
}


// MARK: Preview
struct NotificationBannerPreview: PreviewProvider {
    static var previews: some View {
        NotificationBanner(
            message: "Location updated",
            isVisible: true
        )
        .padding()
        .previewLayout(.sizeThatFits)
        .frame(height: 100)
    }
}
