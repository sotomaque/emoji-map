import SwiftUI

struct CategorySelector: View {
    // MARK: - Properties
    
    // View model (simplified for now)
    @State private var selectedCategories: Set<String> = []
    @State private var isAllCategoriesMode: Bool = true
    @State private var showFavoritesOnly: Bool = false
    @State private var isLoading: Bool = false
    
    // Hard-coded emoji categories as requested
    private let categories: [(String, String)] = [
        ("🍔", "burger"),
        ("🌮", "taco"),
        ("🥗", "salad"),
        ("🥪", "sandwich"),
        ("🍕", "pizza"),
        ("🍟", "fries"),
        ("🍗", "chicken")
    ]
    
    // Haptic feedback
    private let selectionFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let scrollFeedback = UIImpactFeedbackGenerator(style: .light)
    private let edgeFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    // Scroll state
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isShuffleActive: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Left Section: Favorites Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    toggleFavoritesFilter()
                    selectionFeedback.impactOccurred(intensity: 0.8)
                }
            }) {
                FavoritesButton(
                    isSelected: showFavoritesOnly,
                    isLoading: isLoading
                )
            }
            .buttonStyle(EmojiButtonStyle())
            .disabled(isLoading)
            .scaleEffect(showFavoritesOnly ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showFavoritesOnly)
            
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
                                    toggleAllCategories()
                                    selectionFeedback.impactOccurred(intensity: 0.8)
                                }
                            }) {
                                AllCategoriesButton(
                                    isSelected: isAllCategoriesMode,
                                    isLoading: isLoading
                                )
                            }
                            .buttonStyle(EmojiButtonStyle())
                            .disabled(isLoading)
                            .id("all") // ID for scrolling
                            .scaleEffect(isAllCategoriesMode ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAllCategoriesMode)
                        
                            // Show all categories in a single row for standard scrolling
                            ForEach(categories, id: \.1) { category in
                                let emoji = category.0
                                let categoryName = category.1
                                let isSelected = selectedCategories.contains(categoryName) && !isAllCategoriesMode
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        toggleCategory(categoryName)
                                        selectionFeedback.impactOccurred(intensity: 0.8)
                                        
                                        // Scroll to the selected category if it's newly selected
                                        if !isAllCategoriesMode && selectedCategories.contains(categoryName) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                scrollProxy.scrollTo(categoryName, anchor: .center)
                                            }
                                        }
                                    }
                                }) {
                                    EmojiButton(
                                        emoji: emoji,
                                        isSelected: isSelected,
                                        isLoading: isLoading
                                    )
                                }
                                .buttonStyle(EmojiButtonStyle())
                                .disabled(isLoading)
                                .id(categoryName) // ID for scrolling
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
                    if !isAllCategoriesMode && !selectedCategories.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                scrollProxy.scrollTo(selectedCategories.first!, anchor: .center)
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
                .onChange(of: selectedCategories) { oldValue, newValue in
                    // If we have a single selected category and not in "All" mode, scroll to it
                    if !isAllCategoriesMode && newValue.count == 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            scrollProxy.scrollTo(newValue.first!, anchor: .center)
                        }
                    } else if isAllCategoriesMode {
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
                    recommendRandomPlace()
                    
                    // Reset shuffle animation after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShuffleActive = false
                    }
                }
            }) {
                ShuffleButton(
                    isSelected: isShuffleActive,
                    isLoading: isLoading
                )
            }
            .buttonStyle(EmojiButtonStyle())
            .disabled(isLoading)
            .scaleEffect(isShuffleActive ? 1.2 : 1.0)
            .rotationEffect(isShuffleActive ? .degrees(180) : .degrees(0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isShuffleActive)
        }
        .padding(.horizontal, 12)
        .opacity(isLoading ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
    
    // MARK: - Actions
    
    private func toggleFavoritesFilter() {
        showFavoritesOnly.toggle()
        // In a real implementation, this would filter places
        print("Toggled favorites filter: \(showFavoritesOnly)")
    }
    
    private func toggleAllCategories() {
        isAllCategoriesMode.toggle()
        
        if isAllCategoriesMode {
            // Clear selected categories when "All" is selected
            selectedCategories.removeAll()
        }
        
        print("Toggled all categories mode: \(isAllCategoriesMode)")
    }
    
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        
        // If no categories are selected, switch to "All" mode
        if selectedCategories.isEmpty {
            isAllCategoriesMode = true
        } else {
            isAllCategoriesMode = false
        }
        
        print("Selected categories: \(selectedCategories)")
    }
    
    private func recommendRandomPlace() {
        // Stub for random place recommendation
        print("Recommending a random place")
    }
}

#Preview {
    VStack {
        CategorySelector()
            .padding(.vertical)
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
} 