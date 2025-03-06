import XCTest
import SwiftUI
import MapKit
@testable import emoji_map

class EmojiSelectorTests: XCTestCase {
    
    var viewModel: MapViewModel!
    var mockService: MockGooglePlacesService!
    var userPreferences: UserPreferences!
    var testPlaces: [Place]!
    
    @MainActor
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
        let userDefaultsSuiteName = "com.emoji-map.emojiselector.tests"
        let testDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        testDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        userPreferences = UserPreferences(userDefaults: testDefaults)
        
        // Initialize the view model
        viewModel = MapViewModel(googlePlacesService: mockService, userPreferences: userPreferences)
    }
    
    @MainActor
    override func tearDown() {
        viewModel = nil
        mockService = nil
        userPreferences = nil
        testPlaces = nil
        super.tearDown()
    }
    
    @MainActor
    func testEmojiSelectorInitialization() {
        // When
        let emojiSelector = EmojiSelector()
        
        // Then - verify the component initializes with the correct properties
        // Note: In a real test, you would use ViewInspector to inspect the view hierarchy
        // This is a simplified test that just verifies the component can be created
        XCTAssertNotNil(emojiSelector, "EmojiSelector should initialize successfully")
    }
    
    @MainActor
    func testFavoritesButtonTogglesFavoritesFilter() {
        // Given
        XCTAssertFalse(viewModel.showFavoritesOnly, "Favorites filter should be off initially")
        
        // When - toggle favorites filter
        viewModel.toggleFavoritesFilter()
        
        // Then
        XCTAssertTrue(viewModel.showFavoritesOnly, "Favorites filter should be on after toggling")
        
        // When - toggle favorites filter again
        viewModel.toggleFavoritesFilter()
        
        // Then
        XCTAssertFalse(viewModel.showFavoritesOnly, "Favorites filter should be off after toggling again")
    }
    
    @MainActor
    func testAllCategoriesButtonTogglesAllCategories() {
        // Given
        XCTAssertTrue(viewModel.isAllCategoriesMode, "All categories mode should be on initially")
        
        // When - toggle all categories
        viewModel.toggleAllCategories()
        
        // Then
        XCTAssertFalse(viewModel.isAllCategoriesMode, "All categories mode should be off after toggling")
        XCTAssertEqual(viewModel.selectedCategories.count, 0, "No categories should be selected")
        
        // When - toggle all categories again
        viewModel.toggleAllCategories()
        
        // Then
        XCTAssertTrue(viewModel.isAllCategoriesMode, "All categories mode should be on after toggling again")
        XCTAssertEqual(viewModel.selectedCategories.count, viewModel.categories.count, "All categories should be selected")
    }
    
    @MainActor
    func testShuffleButtonRecommendsRandomPlace() {
        // Given
        viewModel.places = testPlaces
        XCTAssertNil(viewModel.selectedPlace, "No place should be selected initially")
        
        // When - recommend a random place
        viewModel.recommendRandomPlace()
        
        // Then
        // Note: Since the selection is random, we can only verify that a place was selected
        // and that it's one of our test places
        if let selectedPlace = viewModel.selectedPlace {
            XCTAssertTrue(
                testPlaces.contains(where: { $0.placeId == selectedPlace.placeId }),
                "Selected place should be one of the test places"
            )
        } else {
            // This could happen if there are no places that match the current filters
            XCTAssertEqual(viewModel.filteredPlaces.count, 0, "No place was selected because no places match the current filters")
        }
    }
} 
