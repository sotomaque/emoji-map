import XCTest
import CoreLocation
import MapKit
@testable import emoji_map

// Mock GooglePlacesService for testing
class MockGooglePlacesService: GooglePlacesServiceProtocol {
    var mockPlaces: [Place] = []
    var mockDetails: PlaceDetails?
    var fetchPlacesCalled = false
    var fetchPlaceDetailsCalled = false
    var lastFetchedCenter: CLLocationCoordinate2D?
    var lastFetchedCategories: [(emoji: String, name: String, type: String)] = []
    var lastFetchedPlaceId: String?
    var lastShowOpenNowOnly: Bool = false
    
    init(mockPlaces: [Place] = [], mockDetails: PlaceDetails? = nil) {
        self.mockPlaces = mockPlaces
        self.mockDetails = mockDetails
    }
    
    func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)], showOpenNowOnly: Bool, completion: @escaping (Result<[Place], NetworkError>) -> Void) {
        fetchPlacesCalled = true
        lastFetchedCenter = center
        lastFetchedCategories = categories
        lastShowOpenNowOnly = showOpenNowOnly
        
        // Filter places by category if needed
        let categoryNames = categories.map { $0.name }
        var filteredPlaces = categoryNames.isEmpty ? mockPlaces : mockPlaces.filter { categoryNames.contains($0.category) }
        
        // Filter by open now if needed
        if showOpenNowOnly {
            filteredPlaces = filteredPlaces.filter { $0.openNow == true }
        }
        
        completion(.success(filteredPlaces))
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        fetchPlaceDetailsCalled = true
        lastFetchedPlaceId = placeId
        
        if let details = mockDetails {
            completion(.success(details))
        } else {
            completion(.failure(.invalidURL))
        }
    }
    
    func cancelPlacesRequests() {
        // No-op for mock
    }
    
    func cancelPlaceDetailsRequests() {
        // No-op for mock
    }
    
    func cancelAllRequests() {
        // No-op for mock
    }
}

@MainActor // Make the test class MainActor-isolated
class MapViewModelTests: XCTestCase {
    var sut: MapViewModel!
    var mockService: MockGooglePlacesService!
    var userPreferences: UserPreferences!
    var testPlaces: [Place]!
    
    @MainActor // Ensure setup runs on the main actor
    override func setUp() {
        super.setUp()
        
        // Create test places
        testPlaces = [
            Place(
                placeId: "pizza_place",
                name: "Pizza Place",
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                category: "pizza",
                description: "A pizza restaurant",
                priceLevel: 2,
                openNow: true,
                rating: 4.2
            ),
            Place(
                placeId: "beer_place",
                name: "Beer Garden",
                coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
                category: "beer",
                description: "A beer garden",
                priceLevel: 3,
                openNow: true,
                rating: 4.5
            ),
            Place(
                placeId: "sushi_place",
                name: "Sushi Bar",
                coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196),
                category: "sushi",
                description: "A sushi restaurant",
                priceLevel: 4,
                openNow: false,
                rating: 4.8
            )
        ]
        
        // Create mock service with test places
        mockService = MockGooglePlacesService(mockPlaces: testPlaces)
        
        // Create test UserPreferences
        let userDefaultsSuiteName = "com.emoji-map.mapviewmodel.tests"
        let testDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        testDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        userPreferences = UserPreferences(userDefaults: testDefaults)
        
        // Initialize the system under test
        sut = MapViewModel(googlePlacesService: mockService, userPreferences: userPreferences)
    }
    
    @MainActor // Ensure tearDown runs on the main actor
    override func tearDown() {
        sut = nil
        mockService = nil
        userPreferences = nil
        testPlaces = nil
        super.tearDown()
    }
    
    // MARK: - Category Filtering Tests
    
    func testInitialCategoriesSelected() {
        // Then
        XCTAssertEqual(sut.selectedCategories.count, 12, "All categories should be selected initially")
        XCTAssertTrue(sut.selectedCategories.contains("pizza"), "Pizza should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("beer"), "Beer should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("sushi"), "Sushi should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("coffee"), "Coffee should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("burger"), "Burger should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("mexican"), "Mexican should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("ramen"), "Ramen should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("salad"), "Salad should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("dessert"), "Dessert should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("wine"), "Wine should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("asian_fusion"), "Asian Fusion should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("sandwich"), "Sandwich should be selected")
    }
    
    func testToggleCategory() {
        // Given - all categories are selected and isAllCategoriesMode is true
        XCTAssertTrue(sut.areAllCategoriesSelected, "All categories should be selected initially")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true initially")
        
        // When - toggle one category (pizza)
        sut.toggleCategory("pizza")
        
        // Then - isAllCategoriesMode should be false, and only pizza should be selected
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should be false after toggling a category")
        XCTAssertEqual(sut.selectedCategories.count, 1, "Should have only 1 category selected")
        XCTAssertTrue(sut.selectedCategories.contains("pizza"), "Pizza should be the only selected category")
        
        // When - toggle pizza again (deselect it)
        sut.toggleCategory("pizza")
        
        // Then - pizza should be deselected and no categories should be selected
        XCTAssertFalse(sut.selectedCategories.contains("pizza"), "Pizza should be deselected")
        XCTAssertEqual(sut.selectedCategories.count, 0, "Should have 0 categories selected")
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should still be false")
        
        // When - toggle pizza again (select it)
        sut.toggleCategory("pizza")
        
        // Then - pizza should be selected again
        XCTAssertTrue(sut.selectedCategories.contains("pizza"), "Pizza should be selected again")
        XCTAssertEqual(sut.selectedCategories.count, 1, "Should have 1 category selected")
    }
    
    func testToggleAllCategories() {
        // Test Case 1: Starting with all categories selected and isAllCategoriesMode = true
        // Given
        XCTAssertTrue(sut.areAllCategoriesSelected, "All categories should be selected initially")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true initially")
        
        // When - toggle all categories (should deselect all)
        sut.toggleAllCategories()
        
        // Then
        XCTAssertEqual(sut.selectedCategories.count, 0, "No categories should be selected")
        XCTAssertFalse(sut.areAllCategoriesSelected, "areAllCategoriesSelected should be false")
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should be false")
        
        // Test Case 2: Starting with no categories selected and isAllCategoriesMode = false
        // When - toggle all categories again (should select all)
        sut.toggleAllCategories()
        
        // Then
        XCTAssertEqual(sut.selectedCategories.count, sut.categories.count, "All categories should be selected")
        XCTAssertTrue(sut.areAllCategoriesSelected, "areAllCategoriesSelected should be true")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true")
        
        // Test Case 3: Clicking "All" button when all categories are selected should clear all
        // When - toggle all categories again (should deselect all)
        sut.toggleAllCategories()
        
        // Then
        XCTAssertEqual(sut.selectedCategories.count, 0, "No categories should be selected")
        XCTAssertFalse(sut.areAllCategoriesSelected, "areAllCategoriesSelected should be false")
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should be false")
        
        // Test Case 4: Clicking "All" button when no categories are selected should select all
        // When - toggle all categories again when already empty
        sut.toggleAllCategories()
        
        // Then
        XCTAssertEqual(sut.selectedCategories.count, sut.categories.count, "All categories should be selected")
        XCTAssertTrue(sut.areAllCategoriesSelected, "areAllCategoriesSelected should be true")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true")
    }
    
    func testToggleCategoryUpdatesAllCategoriesMode() {
        // Given - all categories are selected and isAllCategoriesMode is true
        XCTAssertTrue(sut.areAllCategoriesSelected, "All categories should be selected initially")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true initially")
        
        // When - toggle one category (pizza) when in All Categories mode
        sut.toggleCategory("pizza")
        
        // Then - isAllCategoriesMode should be false, and only pizza should be selected
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should be false after toggling a category")
        XCTAssertEqual(sut.selectedCategories.count, 1, "Should have only 1 category selected")
        XCTAssertTrue(sut.selectedCategories.contains("pizza"), "Pizza should be the only selected category")
        
        // When - toggle another category (beer) when not in All Categories mode
        sut.toggleCategory("beer")
        
        // Then - isAllCategoriesMode should still be false, and both pizza and beer should be selected
        // This is because when not in All Categories mode, toggleCategory adds/removes from the set
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should still be false")
        XCTAssertEqual(sut.selectedCategories.count, 2, "Should have 2 categories selected")
        XCTAssertTrue(sut.selectedCategories.contains("beer"), "Beer should be selected")
        XCTAssertTrue(sut.selectedCategories.contains("pizza"), "Pizza should still be selected")
        
        // When - toggle all categories
        sut.toggleAllCategories()
        
        // Then - all categories should be selected and isAllCategoriesMode should be true
        XCTAssertTrue(sut.areAllCategoriesSelected, "All categories should be selected")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true when all categories are selected")
        
        // When - toggle all categories again
        sut.toggleAllCategories()
        
        // Then - no categories should be selected and isAllCategoriesMode should be false
        XCTAssertEqual(sut.selectedCategories.count, 0, "No categories should be selected")
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should be false when no categories are selected")
    }
    
    // MARK: - Favorites Filtering Tests
    
    func testFilteredPlacesWithNoFavorites() {
        // Given
        sut.places = testPlaces
        
        // When
        sut.showFavoritesOnly = true
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 0, "Should show 0 places when favorites filter is on but no favorites exist")
    }
    
    func testFilteredPlacesWithFavorites() {
        // Given
        sut.places = testPlaces
        userPreferences.addFavorite(testPlaces[0]) // Add pizza place as favorite
        
        // When
        sut.showFavoritesOnly = true
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 1, "Should show 1 place when favorites filter is on")
        XCTAssertEqual(sut.filteredPlaces[0].placeId, "pizza_place", "Should show the pizza place")
    }
    
    func testFilteredPlacesWithFavoritesAndCategories() {
        // Given
        sut.places = testPlaces
        userPreferences.addFavorite(testPlaces[0]) // Add pizza place as favorite
        userPreferences.addFavorite(testPlaces[1]) // Add beer place as favorite
        
        // When
        sut.showFavoritesOnly = true
        sut.selectedCategories = ["pizza"] // Only select pizza category
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 1, "Should show 1 place when favorites filter is on and only pizza category is selected")
        XCTAssertEqual(sut.filteredPlaces[0].placeId, "pizza_place", "Should show the pizza place")
    }
    
    func testFilteredPlacesWithFavoritesAndNoCategories() {
        // Given
        sut.places = testPlaces
        userPreferences.addFavorite(testPlaces[0]) // Add pizza place as favorite
        userPreferences.addFavorite(testPlaces[1]) // Add beer place as favorite
        
        // When
        sut.showFavoritesOnly = true
        sut.selectedCategories.removeAll() // Clear all categories
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 2, "Should show all favorites when no categories are selected")
    }
    
    func testFilteredPlacesWithNoFavoritesFilter() {
        // Given
        sut.places = testPlaces
        userPreferences.addFavorite(testPlaces[0]) // Add pizza place as favorite
        
        // When
        sut.showFavoritesOnly = false
        sut.selectedCategories = ["pizza", "beer"] // Select pizza and beer categories
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 2, "Should show places from selected categories regardless of favorite status")
    }
    
    // MARK: - Favorites Management Tests
    
    func testToggleFavorite() {
        // Given
        let place = testPlaces[0]
        XCTAssertFalse(sut.isFavorite(placeId: place.placeId), "Precondition: Place should not be favorite")
        
        // When
        sut.toggleFavorite(for: place)
        
        // Then
        XCTAssertTrue(sut.isFavorite(placeId: place.placeId), "Place should be marked as favorite")
        
        // When
        sut.toggleFavorite(for: place)
        
        // Then
        XCTAssertFalse(sut.isFavorite(placeId: place.placeId), "Place should no longer be favorite")
    }
    
    // MARK: - Price Level Filtering Tests
    
    @MainActor
    func testFilteredPlacesByPriceLevel() {
        // Given
        sut.places = testPlaces
        
        // When - filter for only $ and $$ places
        // Create a FiltersView to apply the price level filter
        let filtersView1 = FiltersView(
            selectedPriceLevels: [1, 2],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        
        // Apply the filters to the view model
        filtersView1.applyFilters()
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 1, "Should show only places with price level 1 or 2")
        XCTAssertEqual(sut.filteredPlaces[0].placeId, "pizza_place", "Should show the pizza place (price level 2)")
        
        // When - filter for only $$$ and $$$$ places
        // Create a FiltersView to apply the price level filter
        let filtersView2 = FiltersView(
            selectedPriceLevels: [3, 4],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        
        // Apply the filters to the view model
        filtersView2.applyFilters()
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 2, "Should show only places with price level 3 or 4")
        XCTAssertTrue(sut.filteredPlaces.contains(where: { $0.placeId == "beer_place" }), "Should include beer place (price level 3)")
        XCTAssertTrue(sut.filteredPlaces.contains(where: { $0.placeId == "sushi_place" }), "Should include sushi place (price level 4)")
        
        // When - filter for all price levels
        // Create a FiltersView to apply the price level filter
        let filtersView3 = FiltersView(
            selectedPriceLevels: [1, 2, 3, 4],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        
        // Apply the filters to the view model
        filtersView3.applyFilters()
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 3, "Should show all places when all price levels are selected")
    }
    
    @MainActor
    func testFilteredPlacesByOpenNow() {
        // Given
        sut.places = testPlaces
        
        // When - filter for only open places
        // Create a FiltersView to apply the open now filter
        let filtersView = FiltersView(
            selectedPriceLevels: sut.selectedPriceLevels,
            showOpenNowOnly: true,
            minimumRating: sut.minimumRating
        )
        
        // Apply the filters to the view model
        filtersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 2, "Should show only places that are open now")
        XCTAssertTrue(sut.filteredPlaces.contains(where: { $0.placeId == "pizza_place" }), "Should include pizza place (open)")
        XCTAssertTrue(sut.filteredPlaces.contains(where: { $0.placeId == "beer_place" }), "Should include beer place (open)")
        XCTAssertFalse(sut.filteredPlaces.contains(where: { $0.placeId == "sushi_place" }), "Should not include sushi place (closed)")
        
        // When - turn off open now filter
        let resetFiltersView = FiltersView(
            selectedPriceLevels: sut.selectedPriceLevels,
            showOpenNowOnly: false,
            minimumRating: sut.minimumRating
        )
        
        // Apply the filters to the view model
        resetFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 3, "Should show all places when open now filter is off")
    }
    
    func testFilteredPlacesByMinimumRating() {
        // Given
        sut.places = testPlaces
        
        // When - filter for places with rating >= 4.5
        sut.minimumRating = 5
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 1, "Should show only places with rating >= 4.5")
        XCTAssertEqual(sut.filteredPlaces[0].placeId, "sushi_place", "Should show the sushi place (rating 4.8)")
        
        // When - filter for places with rating >= 4.0
        sut.minimumRating = 4
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 3, "Should show all places with rating >= 4.0")
        
        // When - no rating filter
        sut.minimumRating = 0
        
        // Then
        XCTAssertEqual(sut.filteredPlaces.count, 3, "Should show all places when no rating filter is applied")
    }
    
    @MainActor
    func testCombinedFilters() {
        // Given
        sut.places = testPlaces
        
        // When - apply multiple filters: open now, price level 2-3, and rating >= 4.5
        // Create a FiltersView to apply all filters
        let filtersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: true,
            minimumRating: 5
        )
        
        // Apply the filters to the view model
        filtersView.applyFilters()
        
        // Then - no places should match all criteria
        XCTAssertEqual(sut.filteredPlaces.count, 0, "No places should match all criteria")
        
        // When - relax rating filter to >= 4.0
        // Create a new FiltersView with the updated rating
        let updatedFiltersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: true,
            minimumRating: 4
        )
        
        // Apply the updated filters
        updatedFiltersView.applyFilters()
        
        // Then - beer place should match
        XCTAssertEqual(sut.filteredPlaces.count, 2, "Two places should match the relaxed criteria")
        XCTAssertTrue(sut.filteredPlaces.contains(where: { $0.placeId == "pizza_place" }), "Should include pizza place")
        XCTAssertTrue(sut.filteredPlaces.contains(where: { $0.placeId == "beer_place" }), "Should include beer place")
    }
    
    @MainActor
    func testActiveFilterCount() {
        // Given - default state (all price levels, no open now, no minimum rating)
        // Create a FiltersView with default filters
        let defaultFiltersView = FiltersView(
            selectedPriceLevels: [1, 2, 3, 4],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        defaultFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.activeFilterCount, 0, "Should have 0 active filters initially")
        
        // When - apply price level filter
        // Create a FiltersView with price level filter
        let priceLevelFiltersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        priceLevelFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.activeFilterCount, 1, "Should have 1 active filter (price level)")
        
        // When - apply open now filter
        let openNowFiltersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: true,
            minimumRating: 0
        )
        openNowFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.activeFilterCount, 2, "Should have 2 active filters (price level, open now)")
        
        // When - apply minimum rating filter
        let ratingFiltersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: true,
            minimumRating: 4
        )
        ratingFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.activeFilterCount, 3, "Should have 3 active filters (price level, open now, minimum rating)")
        
        // When - reset price level filter
        let resetPriceLevelFiltersView = FiltersView(
            selectedPriceLevels: [1, 2, 3, 4],
            showOpenNowOnly: true,
            minimumRating: 4
        )
        resetPriceLevelFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.activeFilterCount, 2, "Should have 2 active filters (open now, minimum rating)")
        
        // When - reset all filters
        let resetAllFiltersView = FiltersView(
            selectedPriceLevels: [1, 2, 3, 4],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        resetAllFiltersView.applyFilters()
        
        // Then
        XCTAssertEqual(sut.activeFilterCount, 0, "Should have 0 active filters after reset")
    }
    
    // MARK: - Rating Tests
    
    func testRatePlace() {
        // Given
        let placeId = testPlaces[0].placeId
        XCTAssertNil(sut.getRating(for: placeId), "Precondition: Place should not have a rating")
        
        // When
        sut.ratePlace(placeId: placeId, rating: 4)
        
        // Then
        XCTAssertEqual(sut.getRating(for: placeId), 4, "Place should have a rating of 4")
    }
    
    func testRatingPlaceUpdatesUserPreferences() {
        // Given
        let placeId = testPlaces[0].placeId
        XCTAssertNil(sut.getRating(for: placeId), "Precondition: Place should not have a rating")
        
        // When
        sut.ratePlace(placeId: placeId, rating: 4)
        
        // Then
        XCTAssertEqual(sut.getRating(for: placeId), 4, "Place should have a rating of 4")
        XCTAssertEqual(userPreferences.getRating(for: placeId), 4, "UserPreferences should store the rating")
        
        // When - update rating
        sut.ratePlace(placeId: placeId, rating: 5)
        
        // Then
        XCTAssertEqual(sut.getRating(for: placeId), 5, "Place should have updated rating of 5")
        XCTAssertEqual(userPreferences.getRating(for: placeId), 5, "UserPreferences should store the updated rating")
        
        // When - clear rating
        sut.ratePlace(placeId: placeId, rating: 0)
        
        // Then
        XCTAssertEqual(sut.getRating(for: placeId), 0, "Place should have rating cleared to 0")
        XCTAssertEqual(userPreferences.getRating(for: placeId), 0, "UserPreferences should store the cleared rating")
    }
    
    // MARK: - Notification Tests
    
    func testShowNotificationMessage() {
        // Given
        XCTAssertFalse(sut.showNotification, "Precondition: No notification should be showing")
        
        // When
        sut.toggleFavoritesFilter() // This calls showNotificationMessage internally
        
        // Then
        XCTAssertTrue(sut.showNotification, "Notification should be showing")
        XCTAssertFalse(sut.notificationMessage.isEmpty, "Notification message should not be empty")
    }
    
    func testShowNotificationMessageWithTimeout() {
        // Given
        XCTAssertFalse(sut.showNotification, "Precondition: No notification should be showing")
        
        // When
        sut.showNotificationMessage("Test notification")
        
        // Then
        XCTAssertTrue(sut.showNotification, "Notification should be showing")
        XCTAssertEqual(sut.notificationMessage, "Test notification", "Notification message should be set correctly")
        
        // Note: We can't easily test the timeout in a unit test without introducing complex expectations
    }
    
    // MARK: - EmojiSelector Tests
    
    func testToggleFavoritesFilterShowsNotification() {
        // Given
        XCTAssertFalse(sut.showFavoritesOnly, "Precondition: Favorites filter should be off")
        XCTAssertFalse(sut.showNotification, "Precondition: No notification should be showing")
        
        // When
        sut.toggleFavoritesFilter()
        
        // Then
        XCTAssertTrue(sut.showFavoritesOnly, "Favorites filter should be on")
        XCTAssertTrue(sut.showNotification, "Notification should be showing")
        XCTAssertFalse(sut.notificationMessage.isEmpty, "Notification message should not be empty")
        
        // When
        sut.toggleFavoritesFilter()
        
        // Then
        XCTAssertFalse(sut.showFavoritesOnly, "Favorites filter should be off")
        XCTAssertTrue(sut.showNotification, "Notification should be showing")
        XCTAssertFalse(sut.notificationMessage.isEmpty, "Notification message should not be empty")
    }
} 
