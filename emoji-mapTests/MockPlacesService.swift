import Foundation
import Combine
import CoreLocation
@testable import emoji_map

/// A mock implementation of the PlacesServiceProtocol for testing purposes
class MockPlacesService: PlacesServiceProtocol {
    // Mock data that tests can configure
    var mockNearbyPlaces: [Place] = []
    var mockPlacesByCategories: [Place] = []
    var mockFilteredPlaces: PlacesResponse = PlacesResponse(results: [], count: 0, cacheHit: false)
    
    // Track which methods were called
    var fetchNearbyPlacesCalled = false
    var fetchNearbyPlacesPublisherCalled = false
    var fetchPlacesByCategoriesCalled = false
    var fetchWithFiltersCalled = false
    var clearCacheCalled = false
    
    // Track method parameters
    var lastFetchLocation: CLLocationCoordinate2D?
    var lastCategoryKeys: [Int]?
    var lastRequestBody: PlaceSearchRequest?
    
    // MARK: - Protocol Methods
    
    @MainActor func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool) async throws -> [Place] {
        fetchNearbyPlacesCalled = true
        lastFetchLocation = location
        return mockNearbyPlaces
    }
    
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error> {
        fetchNearbyPlacesPublisherCalled = true
        lastFetchLocation = location
        return Just(mockNearbyPlaces)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool = false) async throws -> [Place] {
        fetchPlacesByCategoriesCalled = true
        lastFetchLocation = location
        lastCategoryKeys = categoryKeys
        return mockPlacesByCategories
    }
    
    @MainActor func fetchWithFilters(location: CLLocationCoordinate2D, requestBody: PlaceSearchRequest) async throws -> PlacesResponse {
        fetchWithFiltersCalled = true
        lastFetchLocation = location
        lastRequestBody = requestBody
        return mockFilteredPlaces
    }
    
    @MainActor func clearCache() {
        clearCacheCalled = true
    }
    
    // MARK: - Helper Methods
    
    /// Reset all tracking variables
    func resetTracking() {
        fetchNearbyPlacesCalled = false
        fetchNearbyPlacesPublisherCalled = false
        fetchPlacesByCategoriesCalled = false
        fetchWithFiltersCalled = false
        clearCacheCalled = false
        
        lastFetchLocation = nil
        lastCategoryKeys = nil
        lastRequestBody = nil
    }
} 