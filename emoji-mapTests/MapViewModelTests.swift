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
    
    init(mockPlaces: [Place] = [], mockDetails: PlaceDetails? = nil) {
        self.mockPlaces = mockPlaces
        self.mockDetails = mockDetails
    }
    
    func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)], completion: @escaping (Result<[Place], NetworkError>) -> Void) {
        fetchPlacesCalled = true
        lastFetchedCenter = center
        lastFetchedCategories = categories
        
        // Filter places by category if needed
        let categoryNames = categories.map { $0.name }
        let filteredPlaces = categoryNames.isEmpty ? mockPlaces : mockPlaces.filter { categoryNames.contains($0.category) }
        
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
        // When
        sut.toggleCategory("pizza")
        
        // Then
        XCTAssertFalse(sut.selectedCategories.contains("pizza"), "Pizza should be deselected")
        XCTAssertEqual(sut.selectedCategories.count, 11, "Should have 11 categories selected")
        
        // When
        sut.toggleCategory("pizza")
        
        // Then
        XCTAssertTrue(sut.selectedCategories.contains("pizza"), "Pizza should be selected again")
        XCTAssertEqual(sut.selectedCategories.count, 12, "Should have 12 categories selected")
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
        
        // When - toggle one category off
        sut.toggleCategory("pizza")
        
        // Then - isAllCategoriesMode should remain true, but areAllCategoriesSelected should be false
        XCTAssertFalse(sut.areAllCategoriesSelected, "Not all categories should be selected")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should still be true")
        
        // When - toggle all categories off except one
        for category in sut.categories.map({ $0.1 }) where category != "pizza" {
            sut.toggleCategory(category)
        }
        
        // Then - only pizza should be off, and isAllCategoriesMode should still be true
        XCTAssertFalse(sut.selectedCategories.contains("pizza"), "Pizza should be deselected")
        XCTAssertEqual(sut.selectedCategories.count, 0, "All categories should be deselected")
        XCTAssertFalse(sut.isAllCategoriesMode, "isAllCategoriesMode should be false when no categories are selected")
        
        // When - toggle all categories back on
        for category in sut.categories.map({ $0.1 }) {
            sut.toggleCategory(category)
        }
        
        // Then - all categories should be selected and isAllCategoriesMode should be true
        XCTAssertTrue(sut.areAllCategoriesSelected, "All categories should be selected")
        XCTAssertTrue(sut.isAllCategoriesMode, "isAllCategoriesMode should be true when all categories are selected")
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
} 
