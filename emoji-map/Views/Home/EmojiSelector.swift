import SwiftUI
import UIKit

struct EmojiSelector: View {
    @EnvironmentObject private var viewModel: MapViewModel
    @State private var showAllCategories = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isShuffleActive = false
    
    // Enhanced feedback for better user experience
    private let selectionFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let scrollFeedback = UIImpactFeedbackGenerator(style: .light)
    private let edgeFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Left Section: Favorites Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleFavoritesFilter()
                    selectionFeedback.impactOccurred(intensity: 0.8)
                }
            }) {
                FavoritesButton(
                    isSelected: viewModel.showFavoritesOnly
                )
            }
            .buttonStyle(EmojiButtonStyle())
            .scaleEffect(viewModel.showFavoritesOnly ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.showFavoritesOnly)
            
            // MARK: - Middle Section: Emoji Categories
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
                            // Add "All" button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    // Toggle all categories instead of just clearing
                                    viewModel.toggleAllCategories()
                                    selectionFeedback.impactOccurred(intensity: 0.8)
                                }
                            }) {
                                AllCategoriesButton(
                                    isSelected: viewModel.isAllCategoriesMode
                                )
                            }
                            .buttonStyle(EmojiButtonStyle())
                            .id("all") // ID for scrolling
                            .scaleEffect(viewModel.isAllCategoriesMode ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isAllCategoriesMode)
                        
                            // Show all categories in a single row for standard scrolling
                            ForEach(viewModel.categoryEmojis, id: \.self) { emoji in
                                let isSelected = viewModel.selectedCategories.contains(emoji) && !viewModel.isAllCategoriesMode
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.toggleCategory(emoji)
                                        selectionFeedback.impactOccurred(intensity: 0.8)
                                        
                                        // Scroll to the selected category if it's newly selected
                                        if !viewModel.isAllCategoriesMode && viewModel.selectedCategories.contains(emoji) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                scrollProxy.scrollTo(emoji, anchor: .center)
                                            }
                                        }
                                    }
                                }) {
                                    EmojiButton(
                                        emoji: emoji,
                                        isSelected: isSelected
                                    )
                                }
                                .buttonStyle(EmojiButtonStyle())
                                .id(emoji) // ID for scrolling
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
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
                    
                    // Initial scroll to selected category if not in "All" mode
                    if !viewModel.isAllCategoriesMode && !viewModel.selectedCategories.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                scrollProxy.scrollTo(viewModel.selectedCategories.first!, anchor: .center)
                            }
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
                // React to changes in selection
                .onChange(of: viewModel.selectedCategories) { oldValue, newValue in
                    // If we have a single selected category and not in "All" mode, scroll to it
                    if !viewModel.isAllCategoriesMode && newValue.count == 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            scrollProxy.scrollTo(newValue.first!, anchor: .center)
                        }
                    } else if viewModel.isAllCategoriesMode {
                        // If in "All" mode, scroll to the "all" button
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            scrollProxy.scrollTo("all", anchor: .center)
                        }
                    }
                }
            }
            
            // MARK: - Right Section: Shuffle Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    // Activate shuffle animation briefly
                    isShuffleActive = true
                    
                    // Recommend a random place
                    viewModel.recommendRandomPlace()
                    
                    // Reset shuffle animation after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShuffleActive = false
                    }
                }
            }) {
                ShuffleButton(
                    isSelected: isShuffleActive
                )
            }
            .buttonStyle(EmojiButtonStyle())
            .disabled(viewModel.filteredPlaces.isEmpty)
            .scaleEffect(isShuffleActive ? 1.2 : 1.0)
            .rotationEffect(isShuffleActive ? .degrees(180) : .degrees(0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isShuffleActive)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

