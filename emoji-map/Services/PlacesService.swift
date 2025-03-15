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

// MARK: - Errors

/// Custom error types for PlacesService
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

// MARK: - Places Service Protocol

/// Protocol defining the places service capabilities
protocol PlacesServiceProtocol {
    @MainActor func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool) async throws -> [Place]
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error>
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int]) async throws -> [Place]
    @MainActor func clearCache()
}

// MARK: - Places Service Implementation

@MainActor
class PlacesService: PlacesServiceProtocol {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlacesService")
    
    // Dependencies
    private let networkService: NetworkServiceProtocol
    
    // Cache for places data
    private var placesCache: [String: (places: [Place], timestamp: Date)] = [:]
    private let cacheExpirationTime: TimeInterval = Configuration.cacheExpirationTime
    
    // MARK: - Initialization
    
    init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
        logger.notice("PlacesService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetches nearby places from the backend using async/await
    /// - Parameters:
    ///   - location: The center of the current viewport
    ///   - useCache: Whether to use cached data if available (default: true)
    /// - Returns: An array of places
    @MainActor
    func fetchNearbyPlaces(
        location: CLLocationCoordinate2D,
        useCache: Bool = true
    ) async throws -> [Place] {
        // Create a cache key based on location
        let cacheKey = createCacheKey(location: location)
        
        // Check if we have cached data and it's still valid
        if useCache, 
           let cachedData = placesCache[cacheKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationTime {
            logger.notice("Using cached places data for location: \(location.latitude), \(location.longitude)")
            return cachedData.places
        }
        
        // Otherwise fetch from the network
        do {
            let queryItems = [URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)")]
            
            logger.notice("Fetching nearby places for location: \(location.latitude), \(location.longitude)")
            
            let response: PlacesResponse = try await networkService.fetch(
                endpoint: .nearbyPlaces,
                queryItems: queryItems,
                authToken: nil
            )
            
            // Cache the results
            placesCache[cacheKey] = (places: response.data, timestamp: Date())
            logger.notice("Cached \(response.data.count) places for location: \(location.latitude), \(location.longitude)")
            
            return response.data
        } catch {
            logger.error("Error fetching places: \(error.localizedDescription)")
            throw mapToPlacesServiceError(error)
        }
    }
    
    /// Fetches places by specific category keys
    /// - Parameters:
    ///   - location: The center of the current viewport
    ///   - categoryKeys: Array of category keys to filter by
    /// - Returns: An array of places matching the specified categories
    @MainActor
    func fetchPlacesByCategories(
        location: CLLocationCoordinate2D,
        categoryKeys: [Int]
    ) async throws -> [Place] {
        // Create a cache key based on location and categories
        let categoriesString = categoryKeys.sorted().map { String($0) }.joined(separator: "-")
        let cacheKey = "\(createCacheKey(location: location))-categories-\(categoriesString)"
        
        // Check if we have cached data and it's still valid
        if let cachedData = placesCache[cacheKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationTime {
            logger.notice("Using cached category-specific places data for location: \(location.latitude), \(location.longitude) and categories: \(categoryKeys)")
            return cachedData.places
        }
        
        // Otherwise fetch from the network
        do {
            // Create query items for each category key
            var queryItems = categoryKeys.map { URLQueryItem(name: "keys", value: "\($0)") }
            
            // Add location parameter
            queryItems.append(URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)"))
            
            logger.notice("Fetching places for categories \(categoryKeys) at location: \(location.latitude), \(location.longitude)")
            
            let response: PlacesResponse = try await networkService.fetch(
                endpoint: .nearbyPlaces,
                queryItems: queryItems,
                authToken: nil
            )
            
            // Cache the results
            placesCache[cacheKey] = (places: response.data, timestamp: Date())
            logger.notice("Cached \(response.data.count) category-specific places for location: \(location.latitude), \(location.longitude) and categories: \(categoryKeys)")
            
            return response.data
        } catch {
            logger.error("Error fetching places by categories: \(error.localizedDescription)")
            throw mapToPlacesServiceError(error)
        }
    }
    
    /// Fetches nearby places from the backend using Combine
    /// - Parameters:
    ///   - location: The center of the current viewport
    ///   - useCache: Whether to use cached data if available (default: true)
    /// - Returns: A publisher that emits an array of places or an error
    @MainActor func fetchNearbyPlacesPublisher(
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
        let queryItems = [URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)")]
        
        logger.notice("Fetching nearby places for location: \(location.latitude), \(location.longitude)")
        
        return networkService.fetchWithPublisher(endpoint: .nearbyPlaces, queryItems: queryItems, authToken: nil)
            .map { (response: PlacesResponse) -> [Place] in
                return response.data
            }
            .handleEvents(receiveOutput: { [weak self] places in
                // Cache the results
                self?.placesCache[cacheKey] = (places: places, timestamp: Date())
                self?.logger.notice("Cached \(places.count) places for location: \(location.latitude), \(location.longitude)")
            }, receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.logger.error("Error fetching places: \(error.localizedDescription)")
                }
            })
            .mapError { [weak self] error -> Error in
                guard let self = self else { return PlacesServiceError.unknownError }
                return self.mapToPlacesServiceError(error)
            }
            .eraseToAnyPublisher()
    }
    
    /// Clears the places cache
    @MainActor func clearCache() {
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
    
    /// Maps network errors to PlacesServiceError
    private func mapToPlacesServiceError(_ error: Error) -> Error {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidURL:
                return PlacesServiceError.invalidURL
            case .serverError(let statusCode, _):
                return PlacesServiceError.serverError(statusCode)
            case .decodingError(let decodingError):
                return PlacesServiceError.decodingError(decodingError)
            default:
                return PlacesServiceError.networkError(networkError)
            }
        }
        
        return error
    }
} 