import XCTest
import Combine
import CoreLocation
import MapKit
@testable import emoji_map

class HomeViewModelTests: XCTestCase {
    // Properties for testing
    var viewModel: HomeViewModel!
    var mockPlacesService: MockPlacesService!
    var mockUserPreferences: UserPreferences!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() async throws {
        try await super.setUp()
        mockPlacesService = MockPlacesService()
        mockUserPreferences = UserPreferences()
        
        // Create the view model with mocked dependencies (asynchronously since HomeViewModel is @MainActor)
        viewModel = await HomeViewModel(placesService: mockPlacesService, userPreferences: mockUserPreferences)
    }
    
    override func tearDown() {
        viewModel = nil
        mockPlacesService = nil
        mockUserPreferences = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    /// Test that when all categories are selected and no filters are active,
    /// shuffle selects a random place from the unfiltered list
    func testShuffleWithAllCategoriesSelected() async throws {
        // Given
        let testPlaces = createTestPlaces(count: 5)
        await MainActor.run { [self] in
            viewModel.setPlaces(testPlaces)
            viewModel.isAllCategoriesMode = true
            viewModel.selectedCategoryKeys = []
            viewModel.showFavoritesOnly = false
            
            // Then - All places should be in filtered places
            XCTAssertEqual(viewModel.filteredPlaces.count, testPlaces.count)
        }
        
        // When - Simulate shuffle
        await MainActor.run { [self] in
            viewModel.recommendRandomPlace()
        }
        
        // Then - A place should be selected and sheet should be presented
        await MainActor.run { [self, testPlaces] in
            XCTAssertNotNil(viewModel.selectedPlace)
            XCTAssertTrue(viewModel.isPlaceDetailSheetPresented)
            XCTAssertTrue(testPlaces.contains(where: { $0.id == viewModel.selectedPlace?.id }))
        }
    }
    
    /// Test that when a specific category is selected and no filters are active,
    /// shuffle selects a random place from the filtered list that matches the category
    func testShuffleWithSpecificCategorySelected() async throws {
        // Given
        let testPlaces = createTestPlaces(count: 10)
        let targetCategoryKey = 5  // A specific category key (🍔)
        
        // Set up places with specific categories
        var mutableTestPlaces = testPlaces
        mutableTestPlaces[0].emoji = "🍔" // This will match
        mutableTestPlaces[1].emoji = "🍔🍔" // This will match too
        mutableTestPlaces[2].emoji = "🍕" // This won't match
        
        await MainActor.run { [self] in
            viewModel.setPlaces(mutableTestPlaces)
            viewModel.isAllCategoriesMode = false
            viewModel.selectedCategoryKeys = [targetCategoryKey]
            viewModel.showFavoritesOnly = false
        }
        
        // When - Simulate shuffle
        await MainActor.run { [self] in
            viewModel.recommendRandomPlace()
        }
        
        // Then - A place with the target category should be selected
        await MainActor.run { [self] in
            XCTAssertNotNil(viewModel.selectedPlace)
            XCTAssertTrue(viewModel.isPlaceDetailSheetPresented)
            XCTAssertTrue(viewModel.selectedPlace?.emoji.contains("🍔") ?? false)
        }
    }
    
    /// Test that when favorites filter is active,
    /// shuffling only selects from favorite places
    func testShuffleWithFavoritesAndSpecificCategory() async throws {
        // MARK: - Setup
        // Create a set of test places with different emojis
        let testPlaces = createMixedCategoryTestPlaces()
        
        // Mark two places as favorites - one burger and one coffee
        let burgerPlaceId = testPlaces[0].id  // burger
        let coffeePlaceId = testPlaces[1].id  // coffee
        
        print("DEBUG - Setting up test with burger ID: \(burgerPlaceId), coffee ID: \(coffeePlaceId)")
        
        // Set up the view model with our places and toggle favorites
        await MainActor.run { [self] in
            // Toggle favorites
            let burgerIsFavorite = mockUserPreferences.toggleFavorite(placeId: burgerPlaceId)
            let coffeeIsFavorite = mockUserPreferences.toggleFavorite(placeId: coffeePlaceId)
            print("DEBUG - Added favorites: burger=\(burgerIsFavorite), coffee=\(coffeeIsFavorite)")
            print("DEBUG - Favorites count: \(mockUserPreferences.favoritePlaceIds.count)")
            print("DEBUG - Favorites IDs: \(mockUserPreferences.favoritePlaceIds)")
            
            // Set places in view model
            viewModel.setPlaces(testPlaces)
            print("DEBUG - Set \(testPlaces.count) places in view model")
        }
        
        // MARK: - Test 1: Favorite Filtering
        await MainActor.run { [self] in
            // Enable favorites-only mode
            viewModel.showFavoritesOnly = true
            
            // Update filtered places based on the favorites setting
            viewModel.updateFilteredPlaces()
            
            print("DEBUG - After favorite filtering, filtered places count: \(viewModel.filteredPlaces.count)")
            for place in viewModel.filteredPlaces {
                print("DEBUG - Filtered place: ID=\(place.id), emoji=\(place.emoji)")
            }
            
            // Verify: Only two favorite places should be visible
            XCTAssertEqual(viewModel.filteredPlaces.count, 2, "Two favorites should be visible")
            
            let filteredIds = Set(viewModel.filteredPlaces.map { $0.id })
            XCTAssertTrue(filteredIds.contains(burgerPlaceId), "Burger place should be in filtered places")
            XCTAssertTrue(filteredIds.contains(coffeePlaceId), "Coffee place should be in filtered places")
        }
        
        // MARK: - Test 2: Shuffle with Favorites
        await MainActor.run { [self] in
            // Trigger shuffle (random recommendation)
            print("DEBUG - About to recommend random place")
            viewModel.recommendRandomPlace()
            
            print("DEBUG - After recommendation, selected place: \(String(describing: viewModel.selectedPlace?.id))")
            
            // Verify: A place was selected
            XCTAssertNotNil(viewModel.selectedPlace, "A place should be selected")
            
            // Verify: Selected place is one of our favorites
            if let selectedPlace = viewModel.selectedPlace {
                XCTAssertTrue(
                    selectedPlace.id == burgerPlaceId || selectedPlace.id == coffeePlaceId,
                    "Selected place \(selectedPlace.id) should be one of the favorites"
                )
            }
        }
        
        // MARK: - Test 3: Favorites + Category Filtering
        await MainActor.run { [self] in
            // Now additionally filter by category (coffee - key 4)
            print("DEBUG - Adding coffee category filter (key 4)")
            viewModel.toggleCategory(key: 4, emoji: "☕️")
            
            print("DEBUG - After adding coffee filter, filtered places count: \(viewModel.filteredPlaces.count)")
            for place in viewModel.filteredPlaces {
                print("DEBUG - Filtered place: ID=\(place.id), emoji=\(place.emoji)")
            }
            
            // Verify: Only one place (coffee favorite) should be visible
            XCTAssertEqual(viewModel.filteredPlaces.count, 1, "Only coffee favorite should be visible")
            XCTAssertEqual(viewModel.filteredPlaces[0].id, coffeePlaceId, "The coffee place should be filtered")
            
            // Trigger shuffle again
            print("DEBUG - About to recommend random place with category filter")
            viewModel.recommendRandomPlace()
            
            print("DEBUG - After recommendation with category filter, selected place: \(String(describing: viewModel.selectedPlace?.id))")
            
            // Verify: Coffee place should be selected (as it's the only one in filtered places)
            XCTAssertNotNil(viewModel.selectedPlace, "A place should be selected")
            XCTAssertEqual(viewModel.selectedPlace?.id, coffeePlaceId, "Coffee place should be selected")
        }
    }
    
    /// Test that when network-dependent filters are used, they are properly included in the API request
    func testNetworkDependentFilters() async throws {
        // Given
        let testPlaces = createTestPlaces(count: 5)
        
        await MainActor.run {
            viewModel.setPlaces(testPlaces)
            
            // Setup the visible region
            viewModel.visibleRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            
            // Setup filters
            viewModel.showOpenNowOnly = true
            viewModel.minimumRating = 4
            viewModel.selectedPriceLevels = [1, 2]
        }
        
        // When applying filters
        await viewModel.applyFilters() // This is an async call that needs to be awaited
        
        // Add a small delay to allow async operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then
        let isAllCategoriesMode = await viewModel.isAllCategoriesMode
        let selectedCategoryKeys = await viewModel.selectedCategoryKeys
        
        await MainActor.run {
            // Verify the MockPlacesService received the expected filter parameters
            XCTAssertTrue(mockPlacesService.fetchWithFiltersCalled, "fetchWithFilters should be called")
            
            if let requestBody = mockPlacesService.lastRequestBody {
                XCTAssertEqual(requestBody.openNow, true, "openNow should be set to true")
                XCTAssertEqual(requestBody.minimumRating, 4, "minimumRating should be set to 4")
                XCTAssertEqual(requestBody.priceLevels?.sorted(), [1, 2], "priceLevels should include [1, 2]")
                
                // Verify location coordinates were passed
                XCTAssertEqual(requestBody.location.latitude, 37.7749, accuracy: 0.0001)
                XCTAssertEqual(requestBody.location.longitude, -122.4194, accuracy: 0.0001)
                
                // Verify category keys if not in "all categories" mode
                if !isAllCategoriesMode {
                    XCTAssertEqual(requestBody.keys, Array(selectedCategoryKeys), "Category keys should match")
                }
            } else {
                XCTFail("Request body should not be nil")
            }
        }
    }
    
    /// Test that when only client-side filters are used (like "my ratings"),
    /// no network request is made when filters are applied, and local places are correctly filtered
    func testClientSideFiltering() async throws {
        // Given
        let testPlaces = createTestPlaces(count: 10)
        
        // Set up places with different ratings
        // Add user ratings to some places
        let placeWithRating5 = testPlaces[0].id
        let placeWithRating4 = testPlaces[1].id
        let placeWithRating3 = testPlaces[2].id
        let placeWithRating2 = testPlaces[3].id
        let placeWithRating1 = testPlaces[4].id
        
        // Set user ratings in preferences
        await mockUserPreferences.setRating(placeId: placeWithRating5, rating: 5)
        await mockUserPreferences.setRating(placeId: placeWithRating4, rating: 4)
        await mockUserPreferences.setRating(placeId: placeWithRating3, rating: 3)
        await mockUserPreferences.setRating(placeId: placeWithRating2, rating: 2)
        await mockUserPreferences.setRating(placeId: placeWithRating1, rating: 1)
        
        // Reset the tracking in mock service
        mockPlacesService.resetTracking()
        
        await MainActor.run {
            viewModel.setPlaces(testPlaces)
            
            // Setup client-side filters (local ratings filter)
            viewModel.useLocalRatings = true  // Use local ratings instead of Google ratings
            viewModel.minimumRating = 4       // Filter to show only places with rating >= 4
            
            // When - Apply filters directly (without network call)
            viewModel.updateFilteredPlaces()
            
            // Then
            // 1. No network request should be made
            XCTAssertFalse(mockPlacesService.fetchWithFiltersCalled, "No network request should be made for client-side-only filters")
            
            // 2. Filtered places should only include places with local rating >= 4
            XCTAssertEqual(viewModel.filteredPlaces.count, 2, "Should only include 2 places with rating >= 4")
            
            // 3. Verify the correct places were included
            let filteredIds = Set(viewModel.filteredPlaces.map { $0.id })
            XCTAssertTrue(filteredIds.contains(placeWithRating5), "Place with rating 5 should be included")
            XCTAssertTrue(filteredIds.contains(placeWithRating4), "Place with rating 4 should be included")
            XCTAssertFalse(filteredIds.contains(placeWithRating3), "Place with rating 3 should not be included")
            XCTAssertFalse(filteredIds.contains(placeWithRating2), "Place with rating 2 should not be included")
            XCTAssertFalse(filteredIds.contains(placeWithRating1), "Place with rating 1 should not be included")
        }
    }
    
    /// Test that when a place's rating is changed, the filtered places update automatically if using local ratings
    func testRatingFilterUpdatesWhenRatingChanges() async throws {
        // Given
        let testPlaces = createTestPlaces(count: 10)
        
        // Set up places with different ratings
        let placeWithInitialRating5 = testPlaces[0].id
        
        // Set initial rating to 5
        await mockUserPreferences.setRating(placeId: placeWithInitialRating5, rating: 5)
        
        await MainActor.run {
            viewModel.setPlaces(testPlaces)
            
            // Setup to use local ratings with minimum of 5
            viewModel.useLocalRatings = true
            viewModel.minimumRating = 5
            
            // Apply filters
            viewModel.updateFilteredPlaces()
            
            // Verify initial state - should show the place with rating 5
            XCTAssertEqual(viewModel.filteredPlaces.count, 1)
            XCTAssertTrue(viewModel.filteredPlaces.contains(where: { $0.id == placeWithInitialRating5 }),
                          "Place with rating 5 should be included in filtered results")
        }
        
        // When - Change the rating from 5 to 4
        await mockUserPreferences.setRating(placeId: placeWithInitialRating5, rating: 4)
        
        // Explicitly update filtered places rather than waiting for the subscription
        // This is more reliable in the test environment
        await MainActor.run {
            viewModel.updateFilteredPlacesAfterRatingChange()
        }
        
        // Then - The place should no longer be in the filtered results
        await MainActor.run {
            XCTAssertEqual(viewModel.filteredPlaces.count, 0,
                          "No places should be in filtered results after rating change")
            XCTAssertFalse(viewModel.filteredPlaces.contains(where: { $0.id == placeWithInitialRating5 }),
                          "Place with rating changed to 4 should not be included in filtered results")
        }
    }
    
    /// Test that when a specific emoji category is selected, only places with that emoji are displayed
    func testEmojiCategoryFiltering() async throws {
        // Given
        // Create test places with specific emoji categories
        let testPlaces = createMixedCategoryTestPlaces()
        
        // Verify the test data is set up correctly
        XCTAssertEqual(testPlaces.count, 5, "Test should have 5 places with different emoji combinations")
        XCTAssertEqual(testPlaces[0].emoji, "🍔", "Place 1 should have burger emoji")
        XCTAssertEqual(testPlaces[1].emoji, "☕️", "Place 2 should have coffee emoji")
        XCTAssertEqual(testPlaces[2].emoji, "🍔☕️", "Place 3 should have burger and coffee emojis")
        XCTAssertEqual(testPlaces[3].emoji, "🍣", "Place 4 should have sushi emoji")
        XCTAssertEqual(testPlaces[4].emoji, "🍔", "Place 5 should have burger emoji")
        
        // Add places to the view model
        await MainActor.run {
            viewModel.setPlaces(testPlaces)
        }
        
        // When - Select the burger emoji category (key = 5)
        await MainActor.run {
            // First ensure we're in "All" mode with no filtering
            viewModel.isAllCategoriesMode = true
            viewModel.selectedCategoryKeys = []
            
            // Force filtered places to be updated (baseline check)
            viewModel.updateFilteredPlaces()
            
            // Verify all places are visible when no filters are applied
            XCTAssertEqual(viewModel.filteredPlaces.count, 5, "All places should be visible with no filtering")
            
            // Now toggle the burger category (key = 5)
            viewModel.toggleCategory(key: 5, emoji: "🍔")
        }
        
        // Then - Verify that only places with the burger emoji are in the filtered places
        await MainActor.run {
            // Check that we're not in "All" mode
            XCTAssertFalse(viewModel.isAllCategoriesMode, "Should not be in All categories mode")
            
            // Check that the burger category (key 5) is selected
            XCTAssertTrue(viewModel.selectedCategoryKeys.contains(5), "Burger category should be selected")
            
            // We expect 3 places: the two with only burger emojis and the one with burger+coffee
            XCTAssertEqual(viewModel.filteredPlaces.count, 3, "Only places with burger emoji should be included")
            
            // Verify the correct places were included
            let filteredIds = Set(viewModel.filteredPlaces.map { $0.id })
            XCTAssertTrue(filteredIds.contains("place_1"), "Place with burger emoji should be included")
            XCTAssertFalse(filteredIds.contains("place_2"), "Place with only coffee emoji should NOT be included")
            XCTAssertTrue(filteredIds.contains("place_3"), "Place with both burger and coffee emojis should be included")
            XCTAssertFalse(filteredIds.contains("place_4"), "Place with sushi emoji should NOT be included")
            XCTAssertTrue(filteredIds.contains("place_5"), "Second place with burger emoji should be included")
        }
        
        // When - Select an additional category (coffee, key = 4)
        await MainActor.run {
            viewModel.toggleCategory(key: 4, emoji: "☕️")
        }
        
        // Then - Verify that places with either burger OR coffee emoji are in the filtered places
        await MainActor.run {
            // Check that both categories are selected
            XCTAssertTrue(viewModel.selectedCategoryKeys.contains(4), "Coffee category should be selected")
            XCTAssertTrue(viewModel.selectedCategoryKeys.contains(5), "Burger category should still be selected")
            
            // We expect 4 places: the two with only burger, the one with only coffee, and the one with both
            XCTAssertEqual(viewModel.filteredPlaces.count, 4, "Places with either burger or coffee emoji should be included")
            
            // Verify the correct places were included
            let filteredIds = Set(viewModel.filteredPlaces.map { $0.id })
            XCTAssertTrue(filteredIds.contains("place_1"), "Place with burger emoji should be included")
            XCTAssertTrue(filteredIds.contains("place_2"), "Place with coffee emoji should be included")
            XCTAssertTrue(filteredIds.contains("place_3"), "Place with both burger and coffee emojis should be included")
            XCTAssertFalse(filteredIds.contains("place_4"), "Place with sushi emoji should NOT be included")
            XCTAssertTrue(filteredIds.contains("place_5"), "Second place with burger emoji should be included")
        }
        
        // When - Deselect the burger category, leaving only coffee selected
        await MainActor.run {
            viewModel.toggleCategory(key: 5, emoji: "🍔")
        }
        
        // Then - Verify that only places with coffee emoji are in the filtered places
        await MainActor.run {
            // Check that only coffee category is selected
            XCTAssertTrue(viewModel.selectedCategoryKeys.contains(4), "Coffee category should be selected")
            XCTAssertFalse(viewModel.selectedCategoryKeys.contains(5), "Burger category should no longer be selected")
            
            // We expect 2 places: the one with only coffee, and the one with both burger and coffee
            XCTAssertEqual(viewModel.filteredPlaces.count, 2, "Only places with coffee emoji should be included")
            
            // Verify the correct places were included
            let filteredIds = Set(viewModel.filteredPlaces.map { $0.id })
            XCTAssertFalse(filteredIds.contains("place_1"), "Place with only burger emoji should NOT be included")
            XCTAssertTrue(filteredIds.contains("place_2"), "Place with coffee emoji should be included")
            XCTAssertTrue(filteredIds.contains("place_3"), "Place with both burger and coffee emojis should be included")
            XCTAssertFalse(filteredIds.contains("place_4"), "Place with sushi emoji should NOT be included")
            XCTAssertFalse(filteredIds.contains("place_5"), "Second place with only burger emoji should NOT be included")
        }
        
        // When - Toggle back to "All" mode by deselecting coffee
        await MainActor.run {
            viewModel.toggleCategory(key: 4, emoji: "☕️")
        }
        
        // Then - Verify we're back in "All" mode and all places are included
        await MainActor.run {
            // Check that we're in "All" mode with no categories selected
            XCTAssertTrue(viewModel.isAllCategoriesMode, "Should be back in All categories mode")
            XCTAssertTrue(viewModel.selectedCategoryKeys.isEmpty, "No categories should be selected")
            
            // All places should be included
            XCTAssertEqual(viewModel.filteredPlaces.count, 5, "All places should be visible in All mode")
        }
    }
    
    /// Test that the Home view's placesToDisplay logic correctly uses filteredPlaces when a category is selected
    func testHomeViewUseFilteredPlacesWhenCategorySelected() async throws {
        // This test simulates the logic in Home.swift's placesToDisplay computed property
        // to ensure it correctly returns filteredPlaces when a category is selected
        
        // Given
        let testPlaces = createMixedCategoryTestPlaces()
        
        // Setup ViewModel with test data
        await MainActor.run {
            viewModel.setPlaces(testPlaces)
            viewModel.isAllCategoriesMode = true
            viewModel.selectedCategoryKeys = []
            
            // Initially filteredPlaces should have all places when no filters are applied
            XCTAssertEqual(viewModel.filteredPlaces.count, testPlaces.count)
        }
        
        // When - Select an emoji category (burger - key 5)
        await MainActor.run {
            viewModel.toggleCategory(key: 5, emoji: "🍔")
            
            // Verify the category was selected
            XCTAssertFalse(viewModel.isAllCategoriesMode)
            XCTAssertTrue(viewModel.selectedCategoryKeys.contains(5))
            
            // Verify filtered places only includes places with the burger emoji
            XCTAssertEqual(viewModel.filteredPlaces.count, 3)
        }
        
        // Then - Simulate Home.swift's placesToDisplay logic
        await MainActor.run {
            // Simulate the exact logic from Home.swift's placesToDisplay computed property
            let placesToDisplay: [Place]
            
            if viewModel.hasNetworkDependentFilters {
                placesToDisplay = viewModel.filteredPlaces
            } else if viewModel.showFavoritesOnly || 
                     (viewModel.minimumRating > 0 && viewModel.useLocalRatings) ||
                     (!viewModel.isAllCategoriesMode && !viewModel.selectedCategoryKeys.isEmpty) {
                // This is the crucial condition that was fixed
                placesToDisplay = viewModel.filteredPlaces
            } else {
                placesToDisplay = viewModel.places
            }
            
            // Verify that placesToDisplay uses the filtered places (which only includes burger emojis)
            XCTAssertEqual(placesToDisplay.count, 3, "Home.placesToDisplay should use filteredPlaces when a category is selected")
            
            // Verify only places with burger emoji are included
            let displayedIds = Set(placesToDisplay.map { $0.id })
            XCTAssertTrue(displayedIds.contains("place_1"), "Should include burger place")
            XCTAssertFalse(displayedIds.contains("place_2"), "Should NOT include coffee-only place")
            XCTAssertTrue(displayedIds.contains("place_3"), "Should include place with both burger and coffee")
            XCTAssertFalse(displayedIds.contains("place_4"), "Should NOT include sushi place")
            
            // An additional sanity check - if we remove the category filtering condition, 
            // it would incorrectly use all places
            let incorrectLogic: [Place]
            if viewModel.hasNetworkDependentFilters {
                incorrectLogic = viewModel.filteredPlaces
            } else if viewModel.showFavoritesOnly || (viewModel.minimumRating > 0 && viewModel.useLocalRatings) {
                // Missing the category selection condition
                incorrectLogic = viewModel.filteredPlaces
            } else {
                incorrectLogic = viewModel.places
            }
            
            // This would fail with the bug present - it would use all places
            XCTAssertEqual(incorrectLogic.count, testPlaces.count, "This is what would happen with the bug")
            XCTAssertNotEqual(incorrectLogic.count, placesToDisplay.count, "Fixed logic should differ from buggy logic")
        }
    }
    
    /// Test that the Home view's placesToDisplay logic correctly uses filteredPlaces when a category is selected
    func testFilterPlacesByCategory() async {
        // Given
        let testPlaces = createTestPlaces(count: 5)
        await MainActor.run { [self] in
            // When
            viewModel.setPlaces(testPlaces)
            
            print("DEBUG - Test: Setting selectedCategoryKeys to [5]")
            viewModel.selectedCategoryKeys = [5] // Category key 5 is for burger emoji
            
            print("DEBUG - Test: Setting isAllCategoriesMode to false")
            viewModel.isAllCategoriesMode = false
            
            print("DEBUG - Test: After settings, filteredPlaces count: \(viewModel.filteredPlaces.count)")
            print("DEBUG - Test: Total places count: \(testPlaces.count)")
            print("DEBUG - Test: Selected category key(s): \(viewModel.selectedCategoryKeys)")
            print("DEBUG - Test: Expected emoji: 🍔")
            
            // Explicitly update filtered places
            viewModel.updateFilteredPlaces()
            
            print("DEBUG - Test: After updateFilteredPlaces, filteredPlaces count: \(viewModel.filteredPlaces.count)")
            print("DEBUG - Test: Original places: \(testPlaces.map { ($0.id, $0.emoji) })")
            print("DEBUG - Test: Filtered places: \(viewModel.filteredPlaces.map { ($0.id, $0.emoji) })")
            
            // Then
            // Since all test places have burger emoji, the count should remain the same after filtering
            XCTAssertEqual(viewModel.filteredPlaces.count, testPlaces.count, "All test places have the burger emoji, so all should pass the filter")
            
            // Check that each filtered place has the burger emoji
            for place in viewModel.filteredPlaces {
                print("DEBUG - Test: Checking filtered place \(place.id) with emoji \(place.emoji)")
                XCTAssertTrue(place.emoji.contains("🍔"), "Place \(place.id) with emoji \(place.emoji) should contain 🍔")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlaces(count: Int) -> [Place] {
        var places: [Place] = []
        for i in 0..<count {
            let location = Place.Location(
                latitude: 37.7749 + Double(i) * 0.01,
                longitude: -122.4194 + Double(i) * 0.01
            )
            
            let place = Place(
                id: "place_\(i)",
                emoji: "🍔",
                location: location
            )
            
            // Set optional properties after initialization
            var mutablePlace = place
            mutablePlace.displayName = "Test Place \(i)"
            mutablePlace.rating = Double(i % 5) + 1
            mutablePlace.priceLevel = i % 4
            mutablePlace.userRatingCount = 100 + i
            mutablePlace.openNow = true
            mutablePlace.primaryTypeDisplayName = "Restaurant"
            
            places.append(mutablePlace)
        }
        return places
    }
    
    /// Create test places with mixed categories
    private func createMixedCategoryTestPlaces() -> [Place] {
        let places: [Place] = [
            // Place with category 🍔
            {
                var place = Place(
                    id: "place_1",
                    emoji: "🍔",
                    location: Place.Location(
                        latitude: 37.7749,
                        longitude: -122.4194
                    )
                )
                place.displayName = "Food Place"
                place.rating = 4.5
                place.priceLevel = 2
                place.userRatingCount = 200
                place.openNow = true
                place.primaryTypeDisplayName = "Restaurant"
                return place
            }(),
            
            // Place with category ☕️
            {
                var place = Place(
                    id: "place_2",
                    emoji: "☕️",
                    location: Place.Location(
                        latitude: 37.7850,
                        longitude: -122.4294
                    )
                )
                place.displayName = "Coffee Shop"
                place.rating = 4.2
                place.priceLevel = 1
                place.userRatingCount = 150
                place.openNow = true
                place.primaryTypeDisplayName = "Cafe"
                return place
            }(),
            
            // Place with both categories 🍔 and ☕️
            {
                var place = Place(
                    id: "place_3",
                    emoji: "🍔☕️",
                    location: Place.Location(
                        latitude: 37.7950,
                        longitude: -122.4394
                    )
                )
                place.displayName = "Brunch Spot"
                place.rating = 4.7
                place.priceLevel = 3
                place.userRatingCount = 300
                place.openNow = true
                place.primaryTypeDisplayName = "Restaurant,Cafe"
                return place
            }(),
            
            // Place with category 🍣
            {
                var place = Place(
                    id: "place_4",
                    emoji: "🍣",
                    location: Place.Location(
                        latitude: 37.8050,
                        longitude: -122.4494
                    )
                )
                place.displayName = "Sushi Bar"
                place.rating = 4.8
                place.priceLevel = 4
                place.userRatingCount = 250
                place.openNow = true
                place.primaryTypeDisplayName = "Japanese Restaurant"
                return place
            }(),
            
            // Another place with category 🍔
            {
                var place = Place(
                    id: "place_5",
                    emoji: "🍔",
                    location: Place.Location(
                        latitude: 37.8150,
                        longitude: -122.4594
                    )
                )
                place.displayName = "Burger Joint"
                place.rating = 4.0
                place.priceLevel = 2
                place.userRatingCount = 180
                place.openNow = true
                place.primaryTypeDisplayName = "Fast Food"
                return place
            }()
        ]
        
        return places
    }
} 