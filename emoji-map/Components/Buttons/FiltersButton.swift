import SwiftUI

struct FiltersButton: View {
    let activeFilterCount: Int
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(activeFilterCount > 0 ? Color.blue : Color.black.opacity(0.1))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Icon
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(activeFilterCount > 0 ? .white : .primary)
                .opacity(isLoading ? 0.5 : 1.0)
            
            // Badge for active filter count
            if activeFilterCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    
                    Text("\(min(activeFilterCount, 9))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                }
                .offset(x: 12, y: -12)
            }
        }
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(activeFilterCount > 0 ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeFilterCount)
    }
}

#Preview {
    HStack(spacing: 20) {
        FiltersButton(activeFilterCount: 0, isLoading: false)
        FiltersButton(activeFilterCount: 3, isLoading: false)
        FiltersButton(activeFilterCount: 5, isLoading: true)
    }
    .padding()
    .previewLayout(.sizeThatFits)
} 