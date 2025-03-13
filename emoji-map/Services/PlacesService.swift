//
//  PlacesService.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import CoreLocation
import Combine
import os.log
import MapKit

// Custom error types for PlacesService
enum PlacesServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for places request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode places data: \(error.localizedDescription)"
        case .serverError(let statusCode):
            return "Server returned error code: \(statusCode)"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

@MainActor
class PlacesService {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlacesService")
    
    // Cache for places data
    private var placesCache: [String: (places: [Place], timestamp: Date)] = [:]
    private let cacheExpirationTime: TimeInterval = Configuration.cacheExpirationTime
    
    // MARK: - Initialization
    init() {
        logger.notice("PlacesService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetches nearby places from the backend
    /// - Parameters:
    ///   - location: The center of the current viewport
    ///   - useCache: Whether to use cached data if available (default: true)
    /// - Returns: A publisher that emits an array of places or an error
    func fetchNearbyPlaces(
        location: CLLocationCoordinate2D,
        useCache: Bool = true
    ) -> AnyPublisher<[Place], Error> {
        // Create a cache key based on location
        let cacheKey = createCacheKey(location: location)
        
        // Check if we have cached data and it's still valid
        if useCache, 
           let cachedData = placesCache[cacheKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationTime {
            logger.notice("Using cached places data for location: \(location.latitude), \(location.longitude)")
            return Just(cachedData.places)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Otherwise fetch from the network
        return fetchPlacesFromNetwork(location: location)
            .handleEvents(receiveOutput: { [weak self] places in
                // Cache the results
                self?.placesCache[cacheKey] = (places: places, timestamp: Date())
                self?.logger.notice("Cached \(places.count) places for location: \(location.latitude), \(location.longitude)")
            }, receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.logger.error("Error fetching places: \(error.localizedDescription)")
                }
            })
            .eraseToAnyPublisher()
    }
    
    /// Clears the places cache
    func clearCache() {
        placesCache.removeAll()
        logger.notice("Places cache cleared")
    }
    
    // MARK: - Private Methods
    
    /// Creates a cache key based on location
    private func createCacheKey(location: CLLocationCoordinate2D) -> String {
        let lat = round(location.latitude * 1000) / 1000
        let lng = round(location.longitude * 1000) / 1000
        return "\(lat),\(lng)"
    }
    
    /// Fetches places from the network
    private func fetchPlacesFromNetwork(
        location: CLLocationCoordinate2D
    ) -> AnyPublisher<[Place], Error> {
        // Start building the URL with the API endpoint
        var urlComponents = URLComponents(url: Configuration.backendURL.appendingPathComponent("api/places/nearby"), resolvingAgainstBaseURL: true)
        
        // Always use the provided location parameter (which should be the viewport center)
        let locationValue = "\(location.latitude),\(location.longitude)"
        logger.notice("Using location parameter: \(locationValue)")
        
        // Set the query items with just the location parameter
        urlComponents?.queryItems = [URLQueryItem(name: "location", value: locationValue)]
        
        guard let url = urlComponents?.url else {
            logger.error("Failed to create URL for nearby places request")
            return Fail(error: PlacesServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        logger.notice("Fetching nearby places from: \(url.absoluteString)")
        
        // Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15 // 15 second timeout
        
        // Return a publisher that will emit the decoded places or an error
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                // Check for HTTP errors
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logger.error("Response is not an HTTP response")
                    throw PlacesServiceError.unknownError
                }
                
                self.logger.notice("Received response with status code: \(httpResponse.statusCode)")
                
                // Check for successful status code (200-299)
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.logger.error("Server returned error status code: \(httpResponse.statusCode)")
                    throw PlacesServiceError.serverError(httpResponse.statusCode)
                }
                
                // Log the raw JSON response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    self.logger.notice("Raw JSON response: \(jsonString)")
                } else {
                    self.logger.error("Could not convert response data to string")
                }
                
                return data
            }
            .mapError { error -> Error in
                if let placesError = error as? PlacesServiceError {
                    return placesError
                }
                
                if let urlError = error as? URLError {
                    self.logger.error("Network error: \(urlError.localizedDescription)")
                    return PlacesServiceError.networkError(urlError)
                }
                
                return PlacesServiceError.unknownError
            }
            .decode(type: PlacesResponse.self, decoder: JSONDecoder())
            .map { response -> [Place] in
                self.logger.notice("Decoded \(response.data.count) places from response")
                return response.data
            }
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    // Log more detailed decoding error information
                    self.logger.error("Decoding error: \(decodingError.localizedDescription)")
                    
                    switch decodingError {
                    case let .keyNotFound(key, context):
                        self.logger.error("Key not found: \(key.stringValue), context: \(context.debugDescription), codingPath: \(context.codingPath.map { $0.stringValue })")
                    case let .valueNotFound(type, context):
                        self.logger.error("Value not found: \(type), context: \(context.debugDescription), codingPath: \(context.codingPath.map { $0.stringValue })")
                    case let .typeMismatch(type, context):
                        self.logger.error("Type mismatch: \(type), context: \(context.debugDescription), codingPath: \(context.codingPath.map { $0.stringValue })")
                    case let .dataCorrupted(context):
                        self.logger.error("Data corrupted: \(context.debugDescription), codingPath: \(context.codingPath.map { $0.stringValue })")
                    @unknown default:
                        self.logger.error("Unknown decoding error: \(decodingError)")
                    }
                    
                    return PlacesServiceError.decodingError(decodingError)
                }
                return error
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
} 