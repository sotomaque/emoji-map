//
//  GooglePlacesService.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//


import Foundation
import MapKit

// MARK: - Network Error Types
enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(statusCode: Int)
    case apiError(message: String)
    case networkConnectionError
    case requestCancelled
    case unknownError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please check the request."
        case .noData:
            return "No data received from the server."
        case .decodingError:
            return "Error decoding the data from the server."
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkConnectionError:
            return "Network connection error. Please check your internet connection."
        case .requestCancelled:
            return "Request was cancelled."
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var shouldShowAlert: Bool {
        switch self {
        case .requestCancelled:
            return false
        default:
            return true
        }
    }
}

protocol GooglePlacesServiceProtocol {
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        categories: [(emoji: String, name: String, type: String)],
        showOpenNowOnly: Bool,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    )
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void)
    
    func cancelAllRequests()
    func cancelPlacesRequests()
    func cancelPlaceDetailsRequests()
}

class GooglePlacesService: GooglePlacesServiceProtocol {
    private let apiKey = Configuration.googlePlacesAPIKey
    private let useMockData = Configuration.isUsingMockKey
    private let mockService = MockGooglePlacesService()
    
    // Serial queue for thread synchronization
    private let taskQueue = DispatchQueue(label: "com.emoji-map.taskQueue")
    
    // Task management for cancellation with thread-safe access
    private var _placesTask: Task<Void, Never>?
    private var placesTask: Task<Void, Never>? {
        get {
            taskQueue.sync {
                return _placesTask
            }
        }
        set {
            taskQueue.async {
                self._placesTask = newValue
            }
        }
    }
    
    private var _placeDetailsTask: Task<Void, Never>?
    private var placeDetailsTask: Task<Void, Never>? {
        get {
            taskQueue.sync {
                return _placeDetailsTask
            }
        }
        set {
            taskQueue.async {
                self._placeDetailsTask = newValue
            }
        }
    }
    
    // Helper method to create properly encoded URLs
    private func createURL(baseURL: String, parameters: [String: String]) -> URL? {
        guard var urlComponents = URLComponents(string: baseURL) else {
            return nil
        }
        
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        return urlComponents.url
    }
    
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        categories: [(emoji: String, name: String, type: String)],
        showOpenNowOnly: Bool = false,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        // Cancel any existing places request
        cancelPlacesRequests()
        
        // If using mock key, use mock data instead of making real API calls
        if useMockData {
            mockService.fetchPlaces(center: center, categories: categories, showOpenNowOnly: showOpenNowOnly, completion: completion)
            return
        }
        
        // Create a new task for this request
        placesTask = Task {
            var allPlaces: [Place] = []
            var encounteredError: NetworkError? = nil
            
            for (_, category, placeType) in categories {
                // Check if task was cancelled
                if Task.isCancelled {
                    completion(.failure(.requestCancelled))
                    return
                }
                
                // Skip if we already encountered an error
                if encounteredError != nil {
                    break
                }
                
                let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
                let location = "\(center.latitude),\(center.longitude)"
                
                // Create properly encoded URL using helper method
                let parameters: [String: String] = [
                    "location": location,
                    "radius": "5000", // 5km radius
                    "type": placeType,
                    "keyword": category,
                    "key": apiKey,
                    "opennow": showOpenNowOnly ? "true" : nil // Add open now parameter if filter is enabled
                ].compactMapValues { $0 } // Remove nil values
                
                guard let url = createURL(baseURL: baseURL, parameters: parameters) else {
                    encounteredError = .invalidURL
                    break
                }
                
                do {
                    // Check if task was cancelled before making the request
                    if Task.isCancelled {
                        completion(.failure(.requestCancelled))
                        return
                    }
                    
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    // Check if task was cancelled after receiving the response
                    if Task.isCancelled {
                        completion(.failure(.requestCancelled))
                        return
                    }
                    
                    // Check HTTP status code
                    guard let httpResponse = response as? HTTPURLResponse else {
                        encounteredError = .unknownError(NSError(domain: "HTTPResponse", code: 0, userInfo: nil))
                        break
                    }
                    
                    // Handle HTTP errors
                    guard (200...299).contains(httpResponse.statusCode) else {
                        encounteredError = .serverError(statusCode: httpResponse.statusCode)
                        break
                    }
                    
                    // Check for empty data
                    guard !data.isEmpty else {
                        encounteredError = .noData
                        break
                    }
                    
                    do {
                        let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                        
                        // Check if API returned an error
                        if let status = response.status, status != "OK" {
                            let errorMessage = response.error_message ?? "Unknown API error"
                            encounteredError = .apiError(message: "\(status): \(errorMessage)")
                            break
                        }
                        
                        let categoryPlaces = response.results.map { result in
                            Place(
                                placeId: result.place_id, 
                                name: result.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: result.geometry.location.lat,
                                    longitude: result.geometry.location.lng
                                ),
                                category: category,
                                description: result.vicinity,
                                priceLevel: result.price_level,
                                openNow: result.opening_hours?.open_now,
                                rating: result.rating
                            )
                        }
                        allPlaces.append(contentsOf: categoryPlaces)
                    } catch {
                        encounteredError = .decodingError
                        print("Decoding error: \(error)")
                        break
                    }
                } catch let urlError as URLError {
                    // Check if the error is due to cancellation
                    if urlError.code == .cancelled {
                        completion(.failure(.requestCancelled))
                        return
                    }
                    
                    // Handle specific URL session errors
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        encounteredError = .networkConnectionError
                    default:
                        encounteredError = .unknownError(urlError)
                    }
                    print("Network error fetching \(category) places: \(urlError)")
                    break
                } catch {
                    encounteredError = .unknownError(error)
                    print("Unknown error fetching \(category) places: \(error)")
                    break
                }
            }
            
            // Check if task was cancelled before returning results
            if Task.isCancelled {
                completion(.failure(.requestCancelled))
                return
            }
            
            // Apply open now filter if enabled
            if showOpenNowOnly {
                allPlaces = allPlaces.filter { $0.openNow == true }
            }
            
            // Return results or error
            if let error = encounteredError {
                completion(.failure(error))
            } else {
                completion(.success(allPlaces))
            }
        }
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        // Cancel any existing place details request
        cancelPlaceDetailsRequests()
        
        // If using mock key, use mock data instead of making real API calls
        if useMockData {
            mockService.fetchPlaceDetails(placeId: placeId, completion: completion)
            return
        }
        
        // Create a new task for this request
        placeDetailsTask = Task {
            let baseURL = "https://maps.googleapis.com/maps/api/place/details/json"
            
            // Create properly encoded URL using helper method
            let parameters: [String: String] = [
                "place_id": placeId,
                "fields": "name,photos,reviews",
                "key": apiKey
            ]
            
            guard let url = createURL(baseURL: baseURL, parameters: parameters) else {
                completion(.failure(.invalidURL))
                return
            }
            
            do {
                // Check if task was cancelled before making the request
                if Task.isCancelled {
                    completion(.failure(.requestCancelled))
                    return
                }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Check if task was cancelled after receiving the response
                if Task.isCancelled {
                    completion(.failure(.requestCancelled))
                    return
                }
                
                // Check HTTP status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.unknownError(NSError(domain: "HTTPResponse", code: 0, userInfo: nil))))
                    return
                }
                
                // Handle HTTP errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                    return
                }
                
                // Check for empty data
                guard !data.isEmpty else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
                    
                    // Check if API returned an error
                    if let status = response.status, status != "OK" {
                        let errorMessage = response.error_message ?? "Unknown API error"
                        completion(.failure(.apiError(message: "\(status): \(errorMessage)")))
                        return
                    }
                    
                    // Create properly encoded photo URLs
                    let photos = response.result.photos?.compactMap { photo -> String? in
                        let photoParameters: [String: String] = [
                            "maxwidth": "400",
                            "photoreference": photo.photo_reference,
                            "key": apiKey
                        ]
                        return createURL(baseURL: "https://maps.googleapis.com/maps/api/place/photo", parameters: photoParameters)?.absoluteString
                    } ?? []
                    
                    let details = PlaceDetails(
                        photos: photos,
                        reviews: response.result.reviews?.map { ($0.author_name, $0.text, $0.rating) } ?? []
                    )
                    completion(.success(details))
                } catch {
                    completion(.failure(.decodingError))
                    print("Decoding error: \(error)")
                }
            } catch let urlError as URLError {
                // Check if the error is due to cancellation
                if urlError.code == .cancelled {
                    completion(.failure(.requestCancelled))
                    return
                }
                
                // Handle specific URL session errors
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    completion(.failure(.networkConnectionError))
                default:
                    completion(.failure(.unknownError(urlError)))
                }
                print("Network error fetching place details: \(urlError)")
            } catch {
                completion(.failure(.unknownError(error)))
                print("Unknown error fetching place details: \(error)")
            }
        }
    }
    
    func cancelAllRequests() {
        cancelPlacesRequests()
        cancelPlaceDetailsRequests()
    }
    
    func cancelPlacesRequests() {
        taskQueue.async {
            self._placesTask?.cancel()
            self._placesTask = nil
        }
    }
    
    func cancelPlaceDetailsRequests() {
        taskQueue.async {
            self._placeDetailsTask?.cancel()
            self._placeDetailsTask = nil
        }
    }
}

// MARK: - Mock Google Places Service
class MockGooglePlacesService: GooglePlacesServiceProtocol {
    var mockPlaces: [Place]?
    var mockDetails: PlaceDetails?
    
    private let defaultMockPlaces: [Place] = [
        Place(placeId: "mock1", name: "Pizza Place", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), category: "pizza", description: "123 Pizza St", priceLevel: 2, openNow: true, rating: 4.5),
        Place(placeId: "mock2", name: "Beer Bar", coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4180), category: "beer", description: "456 Beer Ave", priceLevel: 3, openNow: true, rating: 4.2),
        Place(placeId: "mock3", name: "Sushi Spot", coordinate: CLLocationCoordinate2D(latitude: 37.7760, longitude: -122.4170), category: "sushi", description: "789 Sushi Blvd", priceLevel: 4, openNow: false, rating: 4.8),
        Place(placeId: "mock4", name: "Coffee Shop", coordinate: CLLocationCoordinate2D(latitude: 37.7770, longitude: -122.4160), category: "coffee", description: "101 Coffee Rd", priceLevel: 1, openNow: true, rating: 3.9),
        Place(placeId: "mock5", name: "Burger Joint", coordinate: CLLocationCoordinate2D(latitude: 37.7780, longitude: -122.4150), category: "burger", description: "202 Burger Ln", priceLevel: 2, openNow: false, rating: 4.0)
    ]
    
    // Create properly encoded URLs for mock photos
    private let defaultMockDetails = PlaceDetails(
        photos: [
            URL(string: "https://via.placeholder.com/300x200.png?text=Photo+1")?.absoluteString ?? "",
            URL(string: "https://via.placeholder.com/300x200.png?text=Photo+2")?.absoluteString ?? "",
            URL(string: "https://via.placeholder.com/300x200.png?text=Photo+3")?.absoluteString ?? ""
        ],
        reviews: [
            ("John Doe", "Great food and atmosphere!", 5),
            ("Jane Smith", "Service was slow, but food was decent.", 3),
            ("Alex Brown", "Loved the sushi!", 4)
        ]
    )
    
    init(mockPlaces: [Place]? = nil, mockDetails: PlaceDetails? = nil) {
        self.mockPlaces = mockPlaces
        self.mockDetails = mockDetails
    }
    
    func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)], showOpenNowOnly: Bool = false, completion: @escaping (Result<[Place], NetworkError>) -> Void) {
        DispatchQueue.main.async {
            var places = self.mockPlaces ?? self.defaultMockPlaces.filter { place in
                categories.contains { $0.name == place.category }
            }
            
            // Apply open now filter if enabled
            if showOpenNowOnly {
                places = places.filter { $0.openNow == true }
            }
            
            completion(.success(places))
        }
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(self.mockDetails ?? self.defaultMockDetails))
        }
    }
    
    func cancelAllRequests() {
        // No-op for mock service
    }
    
    func cancelPlacesRequests() {
        // No-op for mock service
    }
    
    func cancelPlaceDetailsRequests() {
        // No-op for mock service
    }
}
