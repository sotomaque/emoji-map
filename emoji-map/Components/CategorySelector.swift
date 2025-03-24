import SwiftUI
import Combine
import os.log
import CoreLocation

struct CategorySelector: View {
    // MARK: - Properties
    
    // Logger for emoji selections
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "CategorySelector")
    
    // ViewModel
    @ObservedObject var viewModel: HomeViewModel
    
    // Emoji categories with keys as provided
    private let categories: [(key: Int, emoji: String, name: String)] = [
        (1, "🍕", "pizza"),
        (2, "🍺", "beer"),
        (3, "🍣", "sushi"),
        (4, "☕️", "coffee"),
        (5, "🍔", "burger"),
        (6, "🌮", "taco"),
        (7, "🍜", "noodles"),
        (8, "🥗", "salad"),
        (9, "🍦", "icecream"),
        (10, "🍷", "wine"),
        (11, "🍲", "stew"),
        (12, "🥪", "sandwich"),
        (13, "🍝", "pasta"),
        (14, "🥩", "steak"),
        (15, "🍗", "chicken"),
        (16, "🍤", "shrimp"),
        (17, "🍛", "curry"),
        (18, "🥘", "paella"),
        (19, "🍱", "bento"),
        (20, "🥟", "dumpling"),
        (21, "🧆", "falafel"),
        (22, "🥐", "croissant"),
        (23, "🍨", "dessert"),
        (24, "🍹", "cocktail"),
        (25, "🍽️", "restaurant")
    ]
    
    // Haptic feedback
    private let selectionFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let scrollFeedback = UIImpactFeedbackGenerator(style: .light)
    private let edgeFeedback = UIImpactFeedbackGenerator(style: .rigid)
    
    // Scroll state
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isShuffleActive: Bool = false
    
    // Grid view state
    @State private var gridOriginRect: CGRect = .zero
    @GestureState private var longPressActive = false
    
    // MARK: - Initialization
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Main horizontal selector
            HStack(spacing: 12) {
                // MARK: - Left Section: Favorites Button
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
                                    // Always provide haptic feedback
                                    selectionFeedback.impactOccurred(intensity: 0.8)
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        // Toggle all categories instead of just clearing
                                        viewModel.toggleAllCategories()
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
                                .scaleEffect(viewModel.isAllCategoriesMode ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isAllCategoriesMode)
                                // Add long press gesture to show grid
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.5)
                                        .updating($longPressActive) { currentState, gestureState, _ in
                                            gestureState = currentState
                                        }
                                        .onEnded { _ in
                                            // Haptic feedback when showing grid
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                viewModel.isCategoryGridViewVisible = true
                                            }
                                        }
                                )
                                .background(
                                    GeometryReader { geometry -> Color in
                                        DispatchQueue.main.async {
                                            gridOriginRect = geometry.frame(in: .global)
                                        }
                                        return Color.clear
                                    }
                                )
                            
                                // Show all categories in a single row for standard scrolling
                                ForEach(categories, id: \.name) { category in
                                    let emoji = category.emoji
                                    let categoryName = category.name
                                    let categoryKey = category.key
                                    let isSelected = viewModel.selectedCategoryKeys.contains(categoryKey) && !viewModel.isAllCategoriesMode
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            viewModel.toggleCategory(key: categoryKey, emoji: emoji)
                                            selectionFeedback.impactOccurred(intensity: 0.8)
                                            
                                            // Scroll to the selected category if it's newly selected
                                            if !viewModel.isAllCategoriesMode && viewModel.selectedCategoryKeys.contains(categoryKey) {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                    scrollProxy.scrollTo(categoryName, anchor: .center)
                                                }
                                            }
                                        }
                                    }) {
                                        EmojiButton(
                                            emoji: emoji,
                                            isSelected: isSelected,
                                            isLoading: viewModel.isLoading
                                        )
                                    }
                                    .buttonStyle(EmojiButtonStyle())
                                    .disabled(viewModel.isLoading)
                                    .id(categoryName) // ID for scrolling
                                    .scaleEffect(isSelected ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                                    // Add long press gesture to show grid
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.5)
                                            .updating($longPressActive) { currentState, gestureState, _ in
                                                gestureState = currentState
                                            }
                                            .onEnded { _ in
                                                // Haptic feedback when showing grid
                                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                    viewModel.isCategoryGridViewVisible = true
                                                }
                                            }
                                    )
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
                        if !viewModel.isAllCategoriesMode && !viewModel.selectedCategoryKeys.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if let firstCategory = categories.first(where: { viewModel.selectedCategoryKeys.contains($0.key) }) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        scrollProxy.scrollTo(firstCategory.name, anchor: .center)
                                    }
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
                    .onChange(of: viewModel.selectedCategoryKeys) { oldValue, newValue in
                        // If we have a single selected category and not in "All" mode, scroll to it
                        if !viewModel.isAllCategoriesMode && newValue.count == 1 {
                            if let firstKey = newValue.first,
                               let firstCategory = categories.first(where: { $0.key == firstKey }) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    scrollProxy.scrollTo(firstCategory.name, anchor: .center)
                                }
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
                        isSelected: isShuffleActive,
                        isLoading: viewModel.isLoading
                    )
                }
                .buttonStyle(EmojiButtonStyle())
                .disabled(viewModel.isLoading)
                .scaleEffect(isShuffleActive ? 1.2 : 1.0)
                .rotationEffect(isShuffleActive ? .degrees(180) : .degrees(0))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isShuffleActive)
            }
            .padding(.horizontal, 12)
            .opacity(viewModel.isLoading ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
            
            // MARK: - Grid View Overlay
            if viewModel.isCategoryGridViewVisible {
                CategoryGridView(
                    viewModel: viewModel,
                    categories: categories,
                    showGridView: $viewModel.isCategoryGridViewVisible,
                    originRect: gridOriginRect
                )
                .transition(.asymmetric(
                    insertion: AnyTransition.scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                    removal: AnyTransition.scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Category Grid View
struct CategoryGridView: View {
    @ObservedObject var viewModel: HomeViewModel
    let categories: [(key: Int, emoji: String, name: String)]
    @Binding var showGridView: Bool  // This is bound to viewModel.isCategoryGridViewVisible
    let originRect: CGRect
    
    // Haptic feedback
    private let selectionFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // Grid layout configuration
    private let columns = [
        GridItem(.adaptive(minimum: 76, maximum: 80), spacing: 16),
        GridItem(.adaptive(minimum: 76, maximum: 80), spacing: 16),
        GridItem(.adaptive(minimum: 76, maximum: 80), spacing: 16),
        GridItem(.adaptive(minimum: 76, maximum: 80), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Select Categories")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.isCategoryGridViewVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // "All" option
            Button {
                selectionFeedback.impactOccurred(intensity: 0.8)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.togglePendingAllCategories()
                }
            } label: {
                HStack {
                    AllCategoriesButton(
                        isSelected: viewModel.isPendingAllCategoriesMode,
                        isLoading: viewModel.isLoading
                    )
                    
                    Text("All Categories")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if viewModel.isPendingAllCategoriesMode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .padding(.horizontal)
            
            // Grid of emoji categories
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(categories, id: \.name) { category in
                        let emoji = category.emoji
                        let categoryName = category.name
                        let categoryKey = category.key
                        let isSelected = viewModel.pendingCategoryKeys.contains(categoryKey) && !viewModel.isPendingAllCategoriesMode
                        
                        Button {
                            selectionFeedback.impactOccurred(intensity: 0.8)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.togglePendingCategory(key: categoryKey)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                EmojiButton(
                                    emoji: emoji,
                                    isSelected: isSelected,
                                    isLoading: viewModel.isLoading
                                )
                                
                                Text(categoryName.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                    }
                }
                .padding()
            }
            
            // Apply button
            Button {
                // Apply pending selections then dismiss
                viewModel.applyPendingCategories()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.isCategoryGridViewVisible = false
                }
            } label: {
                Text("Apply (\(viewModel.isPendingAllCategoriesMode ? "All" : "\(viewModel.pendingCategoryKeys.count)"))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor)
                    )
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
        )
        .frame(width: min(UIScreen.main.bounds.width - 32, 400))
        .onAppear {
            selectionFeedback.prepare()
            viewModel.initializePendingCategories()
        }
    }
}

#Preview {
    VStack {
        // Create a mock HomeViewModel for the preview
        let mockService = MockPlacesService()
        let mockUserPreferences = UserPreferences(userDefaults: UserDefaults.standard)
        let viewModel = HomeViewModel(placesService: mockService, userPreferences: mockUserPreferences)
        
        CategorySelector(viewModel: viewModel)
            .padding(.vertical)
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

// Mock service for preview
private class MockPlacesService: PlacesServiceProtocol {
    func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, radius: Int) async throws -> [Place] {
        return []
    }
    
    func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, openNow: Bool?, priceLevels: [Int]?, minimumRating: Int?, radius: Int) async throws -> [Place] {
        return []
    }
    
    func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool, radius: Int) async throws -> [Place] {
        []
    }
    
    func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, openNow: Bool?, priceLevels: [Int]?, minimumRating: Int?) async throws -> [Place] {
        []
    }
    
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool = false) async throws -> [Place] {
        return []
    }
    
    @MainActor func fetchWithFilters(location: CLLocationCoordinate2D, requestBody: PlaceSearchRequest) async throws -> PlacesResponse {
        return PlacesResponse(results: [], count: 0, cacheHit: false)
    }
    
    @MainActor func clearCache() {
        // No-op for preview
    }
} 
