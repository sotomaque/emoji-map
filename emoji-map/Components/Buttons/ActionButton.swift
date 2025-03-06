import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let foregroundColor: Color
    let backgroundColor: Color
    var hasBorder: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasBorder ? foregroundColor : Color.clear, lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ActionButton(
            title: "Add to Favorites",
            icon: "star.fill",
            foregroundColor: .white,
            backgroundColor: .blue,
            action: {}
        )
        
        ActionButton(
            title: "View on Map",
            icon: "map.fill",
            foregroundColor: .blue,
            backgroundColor: Color.blue.opacity(0.1),
            hasBorder: true,
            action: {}
        )
    }
    .padding()
    .previewLayout(.sizeThatFits)
} 