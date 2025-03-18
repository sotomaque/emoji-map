import XCTest
import Combine
import CoreLocation
@testable import emoji_map

class SimplifiedTest: XCTestCase {
    var viewModel: HomeViewModel!
    var mockPlacesService: MockPlacesService!
    var mockUserPreferences: UserPreferences!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockPlacesService = MockPlacesService()
        mockUserPreferences = UserPreferences()
        
        // Create the view model with mocked dependencies
        viewModel = await HomeViewModel(placesService: mockPlacesService, userPreferences: mockUserPreferences)
    }
    
    func testSimple() async throws {
        XCTAssertNotNil(viewModel)
        
        // Add a test place
        await MainActor.run {
            let location = Place.Location(latitude: 37.7749, longitude: -122.4194)
            var place = Place(id: "test_place", emoji: "🍔", location: location)
            place.displayName = "Test Place"
            
            viewModel.places = [place]
            viewModel.filteredPlaces = [place]
        }
        
        // This should be called with MainActor.run since it's a @MainActor method
        await MainActor.run {
            viewModel.recommendRandomPlace()
        }
        
        // Verify results on the main actor
        await MainActor.run {
            XCTAssertNotNil(viewModel.selectedPlace)
            XCTAssertTrue(viewModel.isPlaceDetailSheetPresented)
        }
    }
} 