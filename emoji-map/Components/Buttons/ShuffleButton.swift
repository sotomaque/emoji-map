import SwiftUI

struct ShuffleButton: View {
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color(.systemBackground))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .opacity(isLoading ? 0.5 : 1.0)
            }
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
            ShuffleButton(isSelected: false, isLoading: false)
            ShuffleButton(isSelected: true, isLoading: false)
            ShuffleButton(isSelected: false, isLoading: true)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
