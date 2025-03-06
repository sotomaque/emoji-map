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
        var filtersView = FiltersView(
            selectedPriceLevels: selectedPriceLevelsValue,
            showOpenNowOnly: showOpenNowValue,
            minimumRating: minimumRatingValue,
            onApplyFilters: nil
        )
        
        // Inject the environment object directly
        filtersView.setViewModel(viewModel)
        
        // Then
        XCTAssertEqual(filtersView.selectedPriceLevels, [1, 3], "FiltersView should initialize with the correct price levels")
        XCTAssertTrue(filtersView.showOpenNowOnly, "FiltersView should initialize with the correct open now value")
        XCTAssertEqual(filtersView.minimumRating, 4, "FiltersView should initialize with the correct minimum rating")
    }
    
    @MainActor
    func testApplyFilters() {
        // Given
        let selectedPriceLevelsValue: Set<Int> = [2, 4]
        let showOpenNowValue = true
        let minimumRatingValue = 3
        
        // Create an expectation for the completion handler
        let expectation = XCTestExpectation(description: "Apply filters")
        
        var filtersView = FiltersView(
            selectedPriceLevels: selectedPriceLevelsValue,
            showOpenNowOnly: showOpenNowValue,
            minimumRating: minimumRatingValue,
            onApplyFilters: {
                expectation.fulfill()
            }
        )
        
        // Inject the environment object directly
        filtersView.setViewModel(viewModel)
        
        // When
        filtersView.applyFilters()
        
        // Wait for the completion handler to be called
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.selectedPriceLevels, [2, 4], "ViewModel should have updated price levels")
        XCTAssertTrue(viewModel.showOpenNowOnly, "ViewModel should have updated open now value")
        XCTAssertEqual(viewModel.minimumRating, 3, "ViewModel should have updated minimum rating")
    }
    
    @MainActor
    func testTogglePriceLevel() {
        // Given
        var filtersView = FiltersView(
            selectedPriceLevels: [1, 2, 3],
            showOpenNowOnly: false,
            minimumRating: 0,
            onApplyFilters: nil
        )
        
        // When - remove a price level
        filtersView.togglePriceLevel(3)
        
        // Then
        XCTAssertEqual(filtersView.selectedPriceLevels, [1, 2], "Should remove price level 3")
        
        // When - add a price level
        filtersView.togglePriceLevel(4)
        
        // Then
        XCTAssertEqual(filtersView.selectedPriceLevels, [1, 2, 4], "Should add price level 4")
        
        // When - try to remove the last price level
        filtersView.togglePriceLevel(1)
        filtersView.togglePriceLevel(2)
        filtersView.togglePriceLevel(4)
        
        // Then - should not allow removing the last price level
        XCTAssertEqual(filtersView.selectedPriceLevels, [4], "Should not allow removing the last price level")
    }
    
    @MainActor
    func testResetFilters() {
        // Given
        var filtersView = FiltersView(
            selectedPriceLevels: [2, 3],
            showOpenNowOnly: true,
            minimumRating: 3,
            onApplyFilters: nil
        )
        
        // When
        filtersView.resetFilters()
        
        // Then
        XCTAssertEqual(filtersView.selectedPriceLevels, [1, 2, 3, 4], "Should reset price levels to all")
        XCTAssertFalse(filtersView.showOpenNowOnly, "Should reset open now to false")
        XCTAssertEqual(filtersView.minimumRating, 0, "Should reset minimum rating to 0")
    }
} 
