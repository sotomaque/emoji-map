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
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

protocol GooglePlacesServiceProtocol {
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        categories: [(emoji: String, name: String, type: String)],
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    )
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void)
}

class GooglePlacesService: GooglePlacesServiceProtocol {
    private let apiKey = Configuration.googlePlacesAPIKey
    
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        categories: [(emoji: String, name: String, type: String)],
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        Task {
            var allPlaces: [Place] = []
            var encounteredError: NetworkError? = nil
            
            for (_, category, placeType) in categories {
                // Skip if we already encountered an error
                if encounteredError != nil {
                    break
                }
                
                let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
                let location = "\(center.latitude),\(center.longitude)"
                let radius = "5000" // 5km radius
                
                // Properly encode URL parameters
                guard var urlComponents = URLComponents(string: baseURL) else {
                    encounteredError = .invalidURL
                    break
                }
                
                urlComponents.queryItems = [
                    URLQueryItem(name: "location", value: location),
                    URLQueryItem(name: "radius", value: radius),
                    URLQueryItem(name: "type", value: placeType),
                    URLQueryItem(name: "keyword", value: category),
                    URLQueryItem(name: "key", value: apiKey)
                ]
                
                guard let url = urlComponents.url else {
                    encounteredError = .invalidURL
                    break
                }
                
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
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
                                description: result.vicinity
                            )
                        }
                        allPlaces.append(contentsOf: categoryPlaces)
                    } catch {
                        encounteredError = .decodingError
                        print("Decoding error: \(error)")
                        break
                    }
                } catch let urlError as URLError {
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
            
            // Return results or error
            if let error = encounteredError {
                completion(.failure(error))
            } else {
                completion(.success(allPlaces))
            }
        }
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        Task {
            let baseURL = "https://maps.googleapis.com/maps/api/place/details/json"
            
            // Properly encode URL parameters
            guard var urlComponents = URLComponents(string: baseURL) else {
                completion(.failure(.invalidURL))
                return
            }
            
            urlComponents.queryItems = [
                URLQueryItem(name: "place_id", value: placeId),
                URLQueryItem(name: "fields", value: "name,photos,reviews"),
                URLQueryItem(name: "key", value: apiKey)
            ]
            
            guard let url = urlComponents.url else {
                completion(.failure(.invalidURL))
                return
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
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
                    
                    let details = PlaceDetails(
                        photos: response.result.photos?.map { "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\($0.photo_reference)&key=\(apiKey)" } ?? [],
                        reviews: response.result.reviews?.map { ($0.author_name, $0.text, $0.rating) } ?? []
                    )
                    completion(.success(details))
                } catch {
                    completion(.failure(.decodingError))
                    print("Decoding error: \(error)")
                }
            } catch let urlError as URLError {
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
}

// MARK: - Mock Google Places Service
class MockGooglePlacesService: GooglePlacesServiceProtocol {
    var mockPlaces: [Place]?
    var mockDetails: PlaceDetails?
    
    private let defaultMockPlaces: [Place] = [
        Place(placeId: "mock1", name: "Pizza Place", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), category: "pizza", description: "123 Pizza St"),
        Place(placeId: "mock2", name: "Beer Bar", coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4180), category: "beer", description: "456 Beer Ave"),
        Place(placeId: "mock3", name: "Sushi Spot", coordinate: CLLocationCoordinate2D(latitude: 37.7760, longitude: -122.4170), category: "sushi", description: "789 Sushi Blvd"),
        Place(placeId: "mock4", name: "Coffee Shop", coordinate: CLLocationCoordinate2D(latitude: 37.7770, longitude: -122.4160), category: "coffee", description: "101 Coffee Rd"),
        Place(placeId: "mock5", name: "Burger Joint", coordinate: CLLocationCoordinate2D(latitude: 37.7780, longitude: -122.4150), category: "burger", description: "202 Burger Ln")
    ]
    
    private let defaultMockDetails = PlaceDetails(
        photos: [
            "https://via.placeholder.com/300x200.png?text=Photo+1",
            "https://via.placeholder.com/300x200.png?text=Photo+2",
            "https://via.placeholder.com/300x200.png?text=Photo+3"
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
    
    func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)], completion: @escaping (Result<[Place], NetworkError>) -> Void) {
        DispatchQueue.main.async {
            let places = self.mockPlaces ?? self.defaultMockPlaces.filter { place in
                categories.contains { $0.name == place.category }
            }
            completion(.success(places))
        }
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(self.mockDetails ?? self.defaultMockDetails))
        }
    }
}
