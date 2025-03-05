import XCTest
@testable import emoji_map

class BasicTest: XCTestCase {
    
    func testBasicFunctionality() {
        // A simple test that doesn't require ViewInspector
        XCTAssertTrue(true, "This test should always pass")
    }
    
    // Make the test async to handle MainActor isolation
    func testMapViewModel() async throws {
        // Test that MapViewModel can be instantiated
        let mockService = MockGooglePlacesService()
        
        // Use MainActor.run to access MainActor-isolated properties
        await MainActor.run {
            let viewModel = MapViewModel(googlePlacesService: mockService)
            
            XCTAssertNotNil(viewModel, "MapViewModel should be instantiated")
            XCTAssertEqual(viewModel.categories.count, 12, "MapViewModel should have 12 categories")
        }
    }
} 