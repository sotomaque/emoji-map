import SwiftUI

struct NotificationBanner: View {
    let message: String
    let isVisible: Bool
    var onAppear: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
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
                        .padding(.bottom, 10) // Reduced bottom padding since we're adding padding in ContentView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            onAppear?()
                        }
                        .frame(maxWidth: .infinity, alignment: .center) // Ensure centered
                }
            }
            .frame(width: geometry.size.width) // Use full width
        }
        .animation(.spring(response: 0.4), value: isVisible)
        .frame(height: 80) // Fixed height to prevent layout issues
        .zIndex(10) // Lower z-index to ensure it's below the emoji selector
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
