//
//  emoji_mapTests.swift
//  emoji-mapTests
//
//  Created by Enrique on 3/2/25.
//

import Testing
import CoreLocation
import MapKit
@testable import emoji_map

struct EmojiMapTests {
    
    // Mock GooglePlacesService for testing
    class MockGooglePlacesService: GooglePlacesService {
        var mockPlaces: [Place] = []
        
        override func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)], completion: @escaping ([Place]) -> Void) {
            completion(mockPlaces)
        }
    }
    
    @Test func testToggleCategory() async throws {
        // Arrange
        let mockService = MockGooglePlacesService()
        let viewModel = MapViewModel(googlePlacesService: mockService)
        
        // Act: Toggle a category on
        viewModel.toggleCategory("pizza")
        
        // Assert: Category is selected
        #expect(viewModel.selectedCategories.contains("pizza"))
        #expect(viewModel.selectedCategories.count == 1)
        
        // Act: Toggle the same category off
        viewModel.toggleCategory("pizza")
        
        // Assert: Category is deselected
        #expect(!viewModel.selectedCategories.contains("pizza"))
        #expect(viewModel.selectedCategories.isEmpty)
    }
    
    @Test func testCategoryEmojiMapping() async throws {
        // Arrange
        let mockService = MockGooglePlacesService()
        let viewModel = MapViewModel(googlePlacesService: mockService)
        
        // Act & Assert: Check emoji mappings
        #expect(viewModel.categoryEmoji(for: "pizza") == "🍕")
        #expect(viewModel.categoryEmoji(for: "beer") == "🍺")
        #expect(viewModel.categoryEmoji(for: "sushi") == "🍣")
        #expect(viewModel.categoryEmoji(for: "coffee") == "☕️")
        #expect(viewModel.categoryEmoji(for: "burger") == "🍔")
        
        // Act & Assert: Unknown category returns default emoji
        #expect(viewModel.categoryEmoji(for: "unknown") == "📍")
    }
    
}
