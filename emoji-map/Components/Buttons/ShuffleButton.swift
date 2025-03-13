import SwiftUI

struct ShuffleButton: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color(.systemBackground))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Image(systemName: "shuffle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
        }
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.7),
            value: isSelected
        )
    }
}


// MARK: Preview
struct ShuffleButtonPreview: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            ShuffleButton(isSelected: false)
            ShuffleButton(isSelected: true)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
