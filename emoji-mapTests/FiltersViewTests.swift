import XCTest
import SwiftUI
import MapKit
@testable import emoji_map

class FiltersViewTests: XCTestCase {
    
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
        let userDefaultsSuiteName = "com.emoji-map.filtersview.tests"
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
    func testFiltersViewInitialization() {
        // Given
        // Define our own filter values
        let selectedPriceLevelsValue: Set<Int> = [1, 3]
        let showOpenNowValue = true
        let minimumRatingValue = 4
        
        // When
        let filtersView = FiltersView(
            selectedPriceLevels: selectedPriceLevelsValue,
            showOpenNowOnly: showOpenNowValue,
            minimumRating: minimumRatingValue
        )
        // Inject the environment object
        let hostingController = UIHostingController(rootView: filtersView.environmentObject(viewModel))
        _ = hostingController.view
        
        // Then
        XCTAssertEqual(filtersView.selectedPriceLevels, [1, 3], "FiltersView should initialize with the correct price levels")
        XCTAssertTrue(filtersView.showOpenNowOnly, "FiltersView should initialize with the correct open now value")
        XCTAssertEqual(filtersView.minimumRating, 4, "FiltersView should initialize with the correct minimum rating")
    }
    
    @MainActor
    func testTogglePriceLevel() {
        // Given
        let filtersView = FiltersView(
            selectedPriceLevels: [1, 2, 3, 4],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        // Inject the environment object
        let hostingController = UIHostingController(rootView: filtersView.environmentObject(viewModel))
        _ = hostingController.view
        
        // When - toggle price level 1 (should remove it)
        filtersView.togglePriceLevel(1)
        
        // Then - Since selectedPriceLevels is a Set, we need to check for membership, not order
        XCTAssertFalse(filtersView.selectedPriceLevels.contains(1), "Price level 1 should be removed")
        XCTAssertEqual(filtersView.selectedPriceLevels.count, 3, "Should have 3 price levels after removing one")
        
        // When - toggle price level 1 again (should add it back)
        filtersView.togglePriceLevel(1)
        
        // Then
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(1), "Price level 1 should be added back")
        XCTAssertEqual(filtersView.selectedPriceLevels.count, 4, "Should have all 4 price levels")
        
        // When - try to deselect all price levels
        filtersView.togglePriceLevel(1)
        filtersView.togglePriceLevel(2)
        filtersView.togglePriceLevel(3)
        
        // Then - should not allow deselecting the last price level
        XCTAssertEqual(filtersView.selectedPriceLevels.count, 1, "Should have exactly 1 price level left")
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(4), "Price level 4 should be the remaining one")
        
        // When - try to deselect the last price level
        filtersView.togglePriceLevel(4)
        
        // Then - should not allow deselecting the last price level
        XCTAssertEqual(filtersView.selectedPriceLevels.count, 1, "Should still have exactly 1 price level")
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(4), "Price level 4 should still be selected")
    }
    
    @MainActor
    func testResetFilters() {
        // Given
        let filtersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: true,
            minimumRating: 4
        )
        // Inject the environment object
        let hostingController = UIHostingController(rootView: filtersView.environmentObject(viewModel))
        _ = hostingController.view
        
        // When
        filtersView.resetFilters()
        
        // Then - Check that all price levels are selected after reset
        XCTAssertEqual(filtersView.selectedPriceLevels.count, 4, "Should have all 4 price levels after reset")
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(1), "Price level 1 should be selected after reset")
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(2), "Price level 2 should be selected after reset")
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(3), "Price level 3 should be selected after reset")
        XCTAssertTrue(filtersView.selectedPriceLevels.contains(4), "Price level 4 should be selected after reset")
        
        XCTAssertFalse(filtersView.showOpenNowOnly, "Open now filter should be off after reset")
        XCTAssertEqual(filtersView.minimumRating, 0, "Minimum rating should be 0 after reset")
    }
    
    @MainActor
    func testGetActiveFilterCount() {
        // Given
        let filtersView = FiltersView(
            selectedPriceLevels: [1, 2, 3, 4],
            showOpenNowOnly: false,
            minimumRating: 0
        )
        // Inject the environment object
        let hostingController = UIHostingController(rootView: filtersView.environmentObject(viewModel))
        _ = hostingController.view
        
        // Then - no active filters
        XCTAssertEqual(filtersView.getActiveFilterCount(), 0, "Should have 0 active filters initially")
        
        // When - apply price level filter
        filtersView.togglePriceLevel(4) // Remove price level 4
        
        // Then
        XCTAssertEqual(filtersView.getActiveFilterCount(), 1, "Should have 1 active filter (price level)")
        
        // When - apply open now filter
        filtersView.showOpenNowOnly = true
        
        // Then
        XCTAssertEqual(filtersView.getActiveFilterCount(), 2, "Should have 2 active filters (price level, open now)")
        
        // When - apply minimum rating filter
        filtersView.minimumRating = 3
        
        // Then
        XCTAssertEqual(filtersView.getActiveFilterCount(), 3, "Should have 3 active filters (price level, open now, minimum rating)")
    }
} 
