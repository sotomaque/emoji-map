import SwiftUI
import UIKit


struct EmojiSelector: View {
    @EnvironmentObject private var viewModel: MapViewModel
    @State private var showAllCategories = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Enhanced feedback for better user experience
    private let selectionFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let scrollFeedback = UIImpactFeedbackGenerator(style: .light)
    private let edgeFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    var body: some View {
        VStack(spacing: 8) {
            // Main horizontal scrolling filter bar
            ScrollViewReader { scrollProxy in
                // Add a container with clipping to prevent overflow
                ZStack {
                    // Background capsule with shadow - with fixed height for better UX
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .frame(height: 64) // Fixed height for better proportions
                    
                    // ScrollView with clipping applied
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Favorites filter button - now integrated into the scroll bar
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.toggleFavoritesFilter()
                                    selectionFeedback.impactOccurred(intensity: 0.8)
                                }
                            }) {
                                FavoritesButton(
                                    isSelected: viewModel.showFavoritesOnly,
                                    isLoading: viewModel.isLoading
                                )
                            }
                            .buttonStyle(EmojiButtonStyle())
                            .disabled(viewModel.isLoading)
                            .id("favorites") // ID for scrolling
                            
                            // Add "All" button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    // Toggle all categories instead of just clearing
                                    viewModel.toggleAllCategories()
                                    selectionFeedback.impactOccurred(intensity: 0.8)
                                }
                            }) {
                                AllCategoriesButton(
                                    isSelected: viewModel.isAllCategoriesMode,
                                    isLoading: viewModel.isLoading
                                )
                            }
                            .buttonStyle(EmojiButtonStyle())
                            .disabled(viewModel.isLoading)
                            .id("all") // ID for scrolling
                        
                            // Show all categories in a single row for standard scrolling
                            ForEach(viewModel.categories, id: \.1) { emoji, category, _ in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.toggleCategory(category)
                                        selectionFeedback.impactOccurred(intensity: 0.8)
                                    }
                                }) {
                                    EmojiButton(
                                        emoji: emoji,
                                        isSelected: viewModel.selectedCategories.contains(category) && !viewModel.isAllCategoriesMode,
                                        isLoading: viewModel.isLoading
                                    )
                                }
                                .buttonStyle(EmojiButtonStyle())
                                .disabled(viewModel.isLoading)
                                .id(category) // ID for scrolling
                            }
                        }
                        .padding(.vertical, 4) // Reduced vertical padding
                        .padding(.horizontal, 16)
                        // Use GeometryReader to detect scroll position
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geometry.frame(in: .named("scrollView")).minX
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Track scroll offset for edge effects
                        scrollOffset = value
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.automatic) // Keep bounce effect for better UX
                    // Apply clipping to prevent overflow
                    .clipShape(Capsule())
                    .frame(height: 64) // Match the height of the background
                }
                // Add scroll position detection for haptic feedback
                .onAppear {
                    // Prepare haptic feedback generators
                    selectionFeedback.prepare()
                    scrollFeedback.prepare()
                    edgeFeedback.prepare()
                    
                    // Scroll to favorites button initially if favorites filter is active
                    if viewModel.showFavoritesOnly {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("favorites", anchor: .leading)
                        }
                    }
                }
                .onChange(of: viewModel.showFavoritesOnly) { oldValue, newValue in
                    if newValue {
                        // Scroll to favorites button when activated
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("favorites", anchor: .leading)
                        }
                    }
                }
                // Simplified gesture for haptic feedback during scrolling
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            if !isDragging {
                                // Initial touch feedback
                                scrollFeedback.impactOccurred(intensity: 0.3)
                                isDragging = true
                            }
                            
                            // Edge feedback when reaching the ends
                            let threshold: CGFloat = 20
                            if scrollOffset > -threshold && value.translation.width > 0 {
                                // Left edge feedback
                                edgeFeedback.impactOccurred(intensity: 0.4)
                            } else if scrollOffset < -1500 && value.translation.width < 0 {
                                // Right edge feedback
                                edgeFeedback.impactOccurred(intensity: 0.4)
                            }
                        }
                        .onEnded { _ in
                            // End of scroll feedback
                            scrollFeedback.impactOccurred(intensity: 0.5)
                            isDragging = false
                        }
                )
            }
        }
        .padding(.horizontal, 12)
        .opacity(viewModel.isLoading ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Favorites Button Component
struct FavoritesButton: View {
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            Image(systemName: isSelected ? "star.fill" : "star")
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .yellow : .gray)
                .opacity(isLoading ? 0.6 : 1.0)
            
            if isLoading && isSelected {
                // Show subtle loading indicator on selected button
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.yellow)
            }
        }
        .frame(width: 42, height: 42)
        .background(
            Circle()
                .fill(
                    isSelected ? Color.yellow.opacity(0.15) : Color.gray.opacity(0.08)
                )
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1)
        )
        .overlay(
            Circle()
                .stroke(isSelected ? Color.yellow.opacity(isLoading ? 0.5 : 1.0) : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1.5)
        )
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - All Categories Button Component
struct AllCategoriesButton: View {
    let isSelected: Bool
    let isLoading: Bool
    
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
                .stroke(isSelected ? Color.blue.opacity(isLoading ? 0.5 : 1.0) : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1.5)
        )
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Emoji Button Component
struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            Text(emoji)
                .font(.system(size: 24))
                .opacity(isLoading ? 0.6 : 1.0)
            
            if isLoading && isSelected {
                // Show subtle loading indicator on selected buttons
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(Color.blue)
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
                .stroke(isSelected ? Color.blue.opacity(isLoading ? 0.5 : 1.0) : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1.5)
        )
        .scaleEffect(isSelected ? (isLoading ? 1.0 : 1.05) : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Custom Button Style
struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

struct EmojiSelector_Previews: PreviewProvider {
    static var previews: some View {
        EmojiSelector()
            .environmentObject(
                MapViewModel(googlePlacesService: MockGooglePlacesService())
            )
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
