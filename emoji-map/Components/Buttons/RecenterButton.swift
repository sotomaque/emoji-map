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
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}


// MARK: Preview
struct RecenterButtonPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RecenterButton(isLoading: false, action: {})
            RecenterButton(isLoading: true, action: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
