import Foundation
import CoreLocation
import MapKit

/// Mock implementation of BackendService for testing
class MockBackendService: BackendService {
    private var mockPlaces: [Place]
    private var mockDetails: PlaceDetails?
    
    init(mockPlaces: [Place] = [], mockDetails: PlaceDetails? = nil) {
        // Initialize properties before calling super.init()
        self.mockDetails = mockDetails
        
        // Default mock places if none are provided
        if mockPlaces.isEmpty {
            self.mockPlaces = [
                Place(
                    placeId: "mock_pizza_1",
                    name: "Mock Pizza Place",
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    category: "pizza",
                    description: "A mock pizza restaurant",
                    priceLevel: 2,
                    openNow: true,
                    rating: 4.2
                ),
                Place(
                    placeId: "mock_beer_1",
                    name: "Mock Beer Garden",
                    coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
                    category: "beer",
                    description: "A mock beer garden",
                    priceLevel: 3,
                    openNow: true,
                    rating: 4.5
                ),
                Place(
                    placeId: "mock_sushi_1",
                    name: "Mock Sushi Bar",
                    coordinate: CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196),
                    category: "sushi",
                    description: "A mock sushi restaurant",
                    priceLevel: 4,
                    openNow: false,
                    rating: 4.8
                )
            ]
        } else {
            self.mockPlaces = mockPlaces
        }
        
        // Call super.init() after initializing all properties
        super.init()
    }
    
    override func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [(emoji: String, name: String, type: String)],
        showOpenNowOnly: Bool,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Filter places based on the provided parameters
            var filteredPlaces = self.mockPlaces
            
            // Filter by category if categories are provided
            if !categories.isEmpty {
                let categoryNames = categories.map { $0.name }
                filteredPlaces = filteredPlaces.filter { place in
                    categoryNames.contains(place.category)
                }
            }
            
            // Filter by open now if required
            if showOpenNowOnly {
                filteredPlaces = filteredPlaces.filter { $0.openNow == true }
            }
            
            // Return the filtered places
            completion(.success(filteredPlaces))
        }
    }
    
    override func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // If mockDetails is provided, use it
            if let mockDetails = self.mockDetails {
                completion(.success(mockDetails))
                return
            }
            
            // Otherwise create default mock place details
            let defaultMockDetails = PlaceDetails(
                photos: [
                    "https://example.com/mock_photo_1.jpg",
                    "https://example.com/mock_photo_2.jpg"
                ],
                reviews: [
                    ("Mock Reviewer 1", "This place is great!", 5),
                    ("Mock Reviewer 2", "Good food, but a bit pricey.", 4)
                ]
            )
            
            completion(.success(defaultMockDetails))
        }
    }
    
    override func cancelPlacesRequests() {
        // No-op for mock
    }
    
    override func cancelPlaceDetailsRequests() {
        // No-op for mock
    }
    
    override func cancelAllRequests() {
        // No-op for mock
    }
} 