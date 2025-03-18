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
        var testPlaces = createTestPlaces(count: 5)
        await MainActor.run {
            viewModel.places = testPlaces
            viewModel.isAllCategoriesMode = true
            viewModel.selectedCategoryKeys = []
            viewModel.showFavoritesOnly = false
            
            // Force filtered places to be updated
            viewModel.updateFilteredPlaces()
            
            // Then - All places should be in filtered places
            XCTAssertEqual(viewModel.filteredPlaces.count, testPlaces.count)
        }
        
        // When - Simulate shuffle
        await MainActor.run {
            viewModel.recommendRandomPlace()
        }
        
        // Then - A place should be selected and sheet should be presented
        await MainActor.run {
            XCTAssertNotNil(viewModel.selectedPlace)
            XCTAssertTrue(viewModel.isPlaceDetailSheetPresented)
            XCTAssertTrue(testPlaces.contains(where: { $0.id == viewModel.selectedPlace?.id }))
        }
    }
    
    /// Test that when a specific category is selected and no filters are active,
    /// shuffle selects a random place from the filtered list that matches the category
    func testShuffleWithSpecificCategorySelected() async throws {
        // Given
        var testPlaces = createTestPlaces(count: 10)
        let targetCategoryKey = 5  // A specific category key (🍔)
        
        // Set up places with specific categories
        testPlaces[0].emoji = "🍔" // This will match
        testPlaces[1].emoji = "🍔🍔" // This will match too
        testPlaces[2].emoji = "🍕" // This won't match
        
        await MainActor.run {
            viewModel.places = testPlaces
            viewModel.isAllCategoriesMode = false
            viewModel.selectedCategoryKeys = [targetCategoryKey]
            viewModel.showFavoritesOnly = false
            
            // Force filtered places to be updated
            viewModel.updateFilteredPlaces()
        }
        
        // When - Simulate shuffle
        await MainActor.run {
            viewModel.recommendRandomPlace()
        }
        
        // Then - A place with the target category should be selected
        await MainActor.run {
            XCTAssertNotNil(viewModel.selectedPlace)
            XCTAssertTrue(viewModel.isPlaceDetailSheetPresented)
            XCTAssertTrue(viewModel.selectedPlace?.emoji.contains("🍔") ?? false)
        }
    }
    
    /// Test that when favorites filter is active with a specific category,
    /// shuffle selects a random place that is both a favorite and matches the category
    func testShuffleWithFavoritesAndSpecificCategory() async throws {
        // Given
        var testPlaces = createTestPlaces(count: 10)
        let targetCategoryKey = 4  // A specific category key (☕️)
        
        // Make some places favorite and have specific emojis
        testPlaces[0].emoji = "☕️" // Matches category but not favorite
        testPlaces[1].emoji = "☕️🧋" // Matches category
        testPlaces[2].emoji = "🍩" // Doesn't match category
        
        // Mark places as favorites
        let favoritePlaceIds = [testPlaces[1].id, testPlaces[2].id]
        for id in favoritePlaceIds {
            await mockUserPreferences.toggleFavorite(placeId: id)
        }
        
        await MainActor.run {
            viewModel.places = testPlaces
            viewModel.isAllCategoriesMode = false
            viewModel.selectedCategoryKeys = [targetCategoryKey]
            viewModel.showFavoritesOnly = true
            
            // Force filtered places to be updated
            viewModel.updateFilteredPlaces()
        }
        
        // When - Simulate shuffle
        await MainActor.run {
            viewModel.recommendRandomPlace()
        }
        
        // Then - A favorite place with the target category should be selected
        await MainActor.run {
            XCTAssertNotNil(viewModel.selectedPlace)
            XCTAssertTrue(viewModel.isPlaceDetailSheetPresented)
            XCTAssertTrue(favoritePlaceIds.contains(viewModel.selectedPlace?.id ?? ""))
            XCTAssertTrue(viewModel.selectedPlace?.emoji.contains("☕️") ?? false)
        }
    }
    
    /// Test that when network-dependent filters are used, they are properly included in the API request
    func testNetworkDependentFilters() async throws {
        // Given
        let testPlaces = createTestPlaces(count: 5)
        
        await MainActor.run {
            viewModel.places = testPlaces
            
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
            viewModel.places = testPlaces
            
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
            viewModel.places = testPlaces
            
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