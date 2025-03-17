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
    
    // MARK: - Initialization
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
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
                            .scaleEffect(viewModel.isAllCategoriesMode ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isAllCategoriesMode)
                        
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
                    recommendRandomPlace()
                    
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
    }
    
    // MARK: - Actions
    
    private func recommendRandomPlace() {
        // Get the filtered places from the view model
        let places = viewModel.filteredPlaces
        
        // Check if we have any places to recommend
        guard !places.isEmpty else {
            logger.notice("Cannot recommend a random place: No places available")
            return
        }
        
        // Select a random place from the filtered places
        if let randomPlace = places.randomElement() {
            logger.notice("Recommending a random place: \(randomPlace.id) (\(randomPlace.emoji))")
            
            // Select the place and show its detail sheet
            viewModel.selectPlace(randomPlace)
        } else {
            logger.notice("Failed to select a random place")
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
    @MainActor func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool) async throws -> [Place] {
        return []
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
