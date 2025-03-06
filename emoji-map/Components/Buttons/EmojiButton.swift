import SwiftUI

// MARK: EmojiButton
struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            Text(emoji)
                .font(.system(size: 24))
                .opacity(isLoading ? 0.8 : 1.0)
            
            if isLoading && isSelected {
                // Show subtle loading indicator on selected buttons
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(Color.blue.opacity(0.7))
            }
        }
        .frame(width: 42, height: 42)
        .background(
            Circle()
                .fill(
                    isSelected ? Color.blue
                        .opacity(isLoading ? 0.1 : 0.15) : Color.gray
                        .opacity(0.08)
                )
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
        )
        .overlay(
            Circle()
                .stroke(
                    isSelected ? Color.blue
                        .opacity(isLoading ? 0.5 : 1.0) : Color.gray
                        .opacity(
                            0.3
                        ),
                    lineWidth: isSelected ? 2 : 1.5
                )
        )
        // Remove scale effect during loading to prevent layout shifts
        .scaleEffect(isSelected && !isLoading ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: FavoritesButton
struct FavoritesButton: View {
    let isSelected: Bool
    var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .opacity(isLoading ? 0.6 : 1.0)
            
            if isLoading && isSelected {
                // Show subtle loading indicator on selected button
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.white)
            }
        }
        .frame(width: 42, height: 42)
        .background(
            Circle()
                .fill(
                    isSelected ? Color.yellow : Color.black
                )
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
        )
        .overlay(
            Circle()
                .stroke(
                    isSelected ? Color.yellow
                        .opacity(isLoading ? 0.5 : 1.0) : Color.black
                    ,
                    lineWidth: isSelected ? 2 : 1.5
                )
        )
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: AllCategoriesButton
struct AllCategoriesButton: View {
    let isSelected: Bool
    var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            Text("All")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .opacity(isLoading ? 0.6 : 1.0)
            
            if isLoading && isSelected {
                // Show subtle loading indicator on selected button
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.white)
            }
        }
        .frame(width: 42, height: 42)
        .background(
            Circle()
                .fill(
                    isSelected ? Color.blue : Color.gray.opacity(0.08)
                )
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
        )
        .overlay(
            Circle()
                .stroke(
                    isSelected ? Color.blue
                        .opacity(isLoading ? 0.5 : 1.0) : Color.gray
                        .opacity(
                            0.3
                        ),
                    lineWidth: isSelected ? 2 : 1.5
                )
        )
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: Preview
struct EmojiButtonPreview: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            FavoritesButton(isSelected: false)
            FavoritesButton(isSelected: true)
            AllCategoriesButton(isSelected: false)
            EmojiButton(emoji: "🍕", isSelected: true)
            EmojiButton(emoji: "🏠", isSelected: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
