import SwiftUI

struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isSelected ? Color.accentColor : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Emoji text
            Text(emoji)
                .font(.system(size: 24))
                .opacity(isLoading ? 0.5 : 1.0)
        }
        .frame(width: 56, height: 56)
    }
}

struct FavoritesButton: View {
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isSelected ? Color.accentColor : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Heart icon
            Image(systemName: isSelected ? "heart.fill" : "heart")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .white : .primary)
                .opacity(isLoading ? 0.5 : 1.0)
        }
        .frame(width: 56, height: 56)
    }
}

struct AllCategoriesButton: View {
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isSelected ? Color.accentColor : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // All icon
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .primary)
                .opacity(isLoading ? 0.5 : 1.0)
        }
        .frame(width: 56, height: 56)
    }
}

struct ShuffleButton: View {
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isSelected ? Color.accentColor : Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Shuffle icon
            Image(systemName: "shuffle")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .primary)
                .opacity(isLoading ? 0.5 : 1.0)
        }
        .frame(width: 56, height: 56)
    }
}

#Preview {
    HStack(spacing: 12) {
        EmojiButton(emoji: "🍔", isSelected: true, isLoading: false)
        EmojiButton(emoji: "🌮", isSelected: false, isLoading: false)
        FavoritesButton(isSelected: true, isLoading: false)
        AllCategoriesButton(isSelected: false, isLoading: false)
        ShuffleButton(isSelected: false, isLoading: false)
    }
    .padding()
} 
