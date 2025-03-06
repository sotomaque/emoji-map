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
} 
