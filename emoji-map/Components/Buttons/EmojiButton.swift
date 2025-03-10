import SwiftUI

// MARK: EmojiButton
struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    var isLoading: Bool = false
    
    // Add animation state
    @State private var animateSelection = false
    
    var body: some View {
        ZStack {
            // Background glow effect for selected items
            if isSelected {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .blur(radius: 4)
                    .scaleEffect(animateSelection ? 1.2 : 1.0)
                    .opacity(animateSelection ? 0.7 : 0.0)
            }
            
            // Main background
            Circle()
                .fill(
                    isSelected ? Color.blue
                        .opacity(isLoading ? 0.1 : 0.15) : Color.gray
                        .opacity(0.08)
                )
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
            
            // Emoji text
            Text(emoji)
                .font(.system(size: 24))
                .opacity(isLoading ? 0.8 : 1.0)
                .scaleEffect(isSelected && !isLoading ? 1.1 : 1.0)
            
            // Border
            Circle()
                .stroke(
                    isSelected ? Color.blue
                        .opacity(isLoading ? 0.5 : 1.0) : Color.gray
                        .opacity(0.3),
                    lineWidth: isSelected ? 2 : 1.5
                )
            
            // Loading indicator
            if isLoading && isSelected {
                // Show subtle loading indicator on selected buttons
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(Color.blue.opacity(0.7))
            }
        }
        .frame(width: 42, height: 42)
        // Remove scale effect during loading to prevent layout shifts
        .scaleEffect(isSelected && !isLoading ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .onChange(of: isSelected) { oldValue, newValue in
            if newValue {
                // Trigger selection animation
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animateSelection = true
                }
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation {
                        animateSelection = false
                    }
                }
            }
        }
    }
}

// MARK: FavoritesButton
struct FavoritesButton: View {
    let isSelected: Bool
    var isLoading: Bool = false
    
    // Add animation state
    @State private var animateStar = false
    
    var body: some View {
        ZStack {
            // Background glow for selected state
            if isSelected {
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .blur(radius: 4)
                    .scaleEffect(animateStar ? 1.3 : 1.0)
                    .opacity(animateStar ? 0.7 : 0.0)
            }
            
            // Main background
            Circle()
                .fill(
                    isSelected ? Color.yellow : Color.black
                )
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
            
            // Star icon
            Image(systemName: "star.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .opacity(isLoading ? 0.6 : 1.0)
                .scaleEffect(animateStar ? 1.2 : 1.0)
                .rotationEffect(animateStar ? .degrees(20) : .degrees(0))
            
            // Border
            Circle()
                .stroke(
                    isSelected ? Color.yellow
                        .opacity(isLoading ? 0.5 : 1.0) : Color.black
                    ,
                    lineWidth: isSelected ? 2 : 1.5
                )
            
            // Loading indicator
            if isLoading && isSelected {
                // Show subtle loading indicator on selected button
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.white)
            }
        }
        .frame(width: 42, height: 42)
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .onChange(of: isSelected) { oldValue, newValue in
            if newValue {
                // Trigger star animation
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animateStar = true
                }
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation {
                        animateStar = false
                    }
                }
            }
        }
    }
}

// MARK: AllCategoriesButton
struct AllCategoriesButton: View {
    let isSelected: Bool
    var isLoading: Bool = false
    
    // Add animation state
    @State private var animateRipple = false
    
    var body: some View {
        ZStack {
            // Background ripple effect for selected state
            if isSelected {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .blur(radius: 4)
                    .scaleEffect(animateRipple ? 1.3 : 1.0)
                    .opacity(animateRipple ? 0.7 : 0.0)
            }
            
            // Main background
            Circle()
                .fill(
                    isSelected ? Color.blue : Color.gray.opacity(0.08)
                )
                .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
            
            // Text
            Text("All")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .opacity(isLoading ? 0.6 : 1.0)
                .scaleEffect(animateRipple ? 1.1 : 1.0)
            
            // Border
            Circle()
                .stroke(
                    isSelected ? Color.blue
                        .opacity(isLoading ? 0.5 : 1.0) : Color.gray
                        .opacity(0.3),
                    lineWidth: isSelected ? 2 : 1.5
                )
            
            // Loading indicator
            if isLoading && isSelected {
                // Show subtle loading indicator on selected button
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.white)
            }
        }
        .frame(width: 42, height: 42)
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .onChange(of: isSelected) { oldValue, newValue in
            if newValue {
                // Trigger ripple animation
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animateRipple = true
                }
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation {
                        animateRipple = false
                    }
                }
            }
        }
    }
}

// MARK: Preview
struct EmojiButtonPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                FavoritesButton(isSelected: false)
                FavoritesButton(isSelected: true)
                AllCategoriesButton(isSelected: false)
                AllCategoriesButton(isSelected: true)
            }
            
            HStack(spacing: 12) {
                EmojiButton(emoji: "🍕", isSelected: true)
                EmojiButton(emoji: "🍺", isSelected: false)
                EmojiButton(emoji: "🍣", isSelected: true)
                EmojiButton(emoji: "☕️", isSelected: false)
            }
            
            HStack(spacing: 12) {
                ShuffleButton(isSelected: false, isLoading: false)
                ShuffleButton(isSelected: true, isLoading: false)
                ShuffleButton(isSelected: false, isLoading: true)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
