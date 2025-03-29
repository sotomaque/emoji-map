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

// MARK: - Models

/// Request model for place search
struct PlaceSearchRequest: Codable, Hashable {
    let keys: [Int]?
    let openNow: Bool?
    let priceLevels: [Int]?
    let radius: Int?
    let location: LocationCoordinate
    let bypassCache: Bool?
    let maxResultCount: Int?
    let minimumRating: Int?
    
    struct LocationCoordinate: Codable, Hashable {
        let latitude: Double
        let longitude: Double
    }
}

// MARK: - Places Service Protocol

/// Protocol defining the places service capabilities
protocol PlacesServiceProtocol {
    @MainActor func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool, radius: Int) async throws -> [Place]
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error>
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, radius: Int) async throws -> [Place]
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, openNow: Bool?, priceLevels: [Int]?, minimumRating: Int?, radius: Int) async throws -> [Place]
    @MainActor func fetchWithFilters(location: CLLocationCoordinate2D, requestBody: PlaceSearchRequest) async throws -> PlacesResponse
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
    ///   - radius: The radius of the search area (in meters)
    /// - Returns: An array of places
    @MainActor
    func fetchNearbyPlaces(
        location: CLLocationCoordinate2D,
        useCache: Bool = true,
        radius: Int = Configuration.defaultSearchRadius
    ) async throws -> [Place] {
        // Create a cache key based on location and radius
        let cacheKey = "\(createCacheKey(location: location))-radius-\(radius)"
        
        // Check if we have cached data and it's still valid
        if useCache, 
           let cachedData = placesCache[cacheKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationTime {
            logger.notice("Using cached places data for location: \(location.latitude), \(location.longitude), radius: \(radius)m")
            return cachedData.places
        }
        
        // Otherwise fetch from the network
        do {
            // Create request body
            let requestBody = PlaceSearchRequest(
                keys: nil, // Use default keys from backend
                openNow: nil,
                priceLevels: nil,
                radius: radius,
                location: PlaceSearchRequest.LocationCoordinate(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                bypassCache: !useCache,
                maxResultCount: nil,
                minimumRating: nil
            )
            
            logger.notice("Fetching nearby places for location: \(location.latitude), \(location.longitude), with radius: \(radius) meters")
            
            let response: PlacesResponse = try await networkService.post(
                endpoint: .placeSearch,
                body: requestBody,
                queryItems: nil,
                authToken: nil
            )
            
            // Cache the results
            placesCache[cacheKey] = (places: response.results, timestamp: Date())
            logger.notice("Cached \(response.results.count) places for location: \(location.latitude), \(location.longitude), radius: \(radius)m")
            
            return response.results
        } catch {
            logger.error("Error fetching places: \(error.localizedDescription)")
            throw mapToPlacesServiceError(error)
        }
    }
    
    /// Fetches places by specific category keys
    /// - Parameters:
    ///   - location: The center of the current viewport
    ///   - categoryKeys: Array of category keys to filter by
    ///   - bypassCache: Whether to bypass the cache and add bypassCache parameter to the request
    ///   - radius: The radius of the search area (in meters)
    /// - Returns: An array of places matching the specified categories
    @MainActor
    func fetchPlacesByCategories(
        location: CLLocationCoordinate2D,
        categoryKeys: [Int],
        bypassCache: Bool = false,
        openNow: Bool? = nil,
        priceLevels: [Int]? = nil,
        minimumRating: Int? = nil,
        radius: Int = Configuration.defaultSearchRadius
    ) async throws -> [Place] {
        // Create a cache key based on location and categories
        let categoriesString = categoryKeys.sorted().map { String($0) }.joined(separator: "-")
        
        // Add filter parameters to cache key
        var filterComponents: [String] = []
        filterComponents.append("categories-\(categoriesString)")
        
        if let openNow = openNow, openNow {
            filterComponents.append("openNow=true")
        }
        
        if let priceLevels = priceLevels, !priceLevels.isEmpty {
            filterComponents.append("priceLevels=\(priceLevels.sorted().map { String($0) }.joined(separator: "-"))")
        }
        
        if let minimumRating = minimumRating, minimumRating > 0 {
            filterComponents.append("minimumRating=\(minimumRating)")
        }
        
        // Add radius to cache key
        filterComponents.append("radius=\(radius)")
        
        // Combine all components to create a cache key
        let filterKey = filterComponents.joined(separator: "&")
        let cacheKey = "\(createCacheKey(location: location))-\(filterKey)"
        
        // Check if we have cached data and it's still valid
        if !bypassCache,
           let cachedData = placesCache[cacheKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationTime {
            logger.notice("Using cached category-specific places data for location: \(location.latitude), \(location.longitude) and categories: \(categoryKeys)")
            return cachedData.places
        }
        
        // Otherwise fetch from the network
        do {
            // Create request body
            let requestBody = PlaceSearchRequest(
                keys: categoryKeys,
                openNow: openNow,
                priceLevels: priceLevels,
                radius: radius, // Use the passed radius parameter
                location: PlaceSearchRequest.LocationCoordinate(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                bypassCache: bypassCache,
                maxResultCount: nil,
                minimumRating: minimumRating
            )
            
            logger.notice("Fetching places for categories \(categoryKeys) at location: \(location.latitude), \(location.longitude), with radius: \(radius) meters")

            let response: PlacesResponse = try await networkService.post(
                endpoint: .placeSearch,
                body: requestBody,
                queryItems: nil,
                authToken: nil
            )
            
            // Cache the results
            placesCache[cacheKey] = (places: response.results, timestamp: Date())
            logger.notice("Cached \(response.results.count) category-specific places for location: \(location.latitude), \(location.longitude) and categories: \(categoryKeys)")
            
            return response.results
        } catch {
            logger.error("Error fetching places by categories: \(error.localizedDescription)")
            throw mapToPlacesServiceError(error)
        }
    }
    
    /// Simple version to conform to protocol - delegates to full version
    @MainActor
    func fetchPlacesByCategories(
        location: CLLocationCoordinate2D,
        categoryKeys: [Int],
        bypassCache: Bool = false,
        radius: Int = Configuration.defaultSearchRadius
    ) async throws -> [Place] {
        return try await fetchPlacesByCategories(
            location: location,
            categoryKeys: categoryKeys,
            bypassCache: bypassCache,
            openNow: nil,
            priceLevels: nil, 
            minimumRating: nil,
            radius: radius
        )
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
        
        // Create request body
        let requestBody = PlaceSearchRequest(
            keys: nil, // Use default keys from backend
            openNow: nil,
            priceLevels: nil,
            radius: Configuration.defaultSearchRadius, // Use Configuration value instead of hardcoding
            location: PlaceSearchRequest.LocationCoordinate(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            bypassCache: !useCache,
            maxResultCount: nil,
            minimumRating: nil
        )
        
        logger.notice("Fetching nearby places for location: \(location.latitude), \(location.longitude)")
        
        // Since we need to use POST but the NetworkService only has fetchWithPublisher for GET,
        // we'll use a Future to wrap our async call
        return Future<[Place], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(PlacesServiceError.unknownError))
                return
            }
            
            Task {
                do {
                    let response: PlacesResponse = try await self.networkService.post(
                        endpoint: .placeSearch,
                        body: requestBody,
                        queryItems: nil,
                        authToken: nil
                    )
                    
                    // Cache the results
                    self.placesCache[cacheKey] = (places: response.results, timestamp: Date())
                    self.logger.notice("Cached \(response.results.count) places for location: \(location.latitude), \(location.longitude)")
                    
                    promise(.success(response.results))
                } catch {
                    self.logger.error("Error fetching places: \(error.localizedDescription)")
                    promise(.failure(self.mapToPlacesServiceError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Fetches places with custom filters
    /// - Parameters:
    ///   - location: The center of the current viewport
    ///   - requestBody: The request body with filter parameters
    /// - Returns: A PlacesResponse containing the filtered places
    @MainActor
    func fetchWithFilters(
        location: CLLocationCoordinate2D,
        requestBody: PlaceSearchRequest
    ) async throws -> PlacesResponse {
        // Create a cache key based on the request body
        let locationKey = createCacheKey(location: location)
        
        // Create a unique key for the filter parameters
        var filterComponents: [String] = []
        
        if let keys = requestBody.keys, !keys.isEmpty {
            filterComponents.append("keys=\(keys.sorted().map { String($0) }.joined(separator: "-"))")
        }
        
        if let openNow = requestBody.openNow {
            filterComponents.append("openNow=\(openNow)")
        }
        
        if let priceLevels = requestBody.priceLevels, !priceLevels.isEmpty {
            filterComponents.append("priceLevels=\(priceLevels.sorted().map { String($0) }.joined(separator: "-"))")
        }
        
        if let minimumRating = requestBody.minimumRating, minimumRating > 0 {
            filterComponents.append("minimumRating=\(minimumRating)")
        }
        
        if let radius = requestBody.radius {
            filterComponents.append("radius=\(radius)")
        }
        
        // Combine all components to create a cache key
        let filterKey = filterComponents.isEmpty ? "no-filters" : filterComponents.joined(separator: "&")
        let cacheKey = "filters-\(locationKey)-\(filterKey)"
        
        // Always force bypassCache to true for filter requests to ensure we get fresh results
        // Create a new request body with bypassCache set to true
        let modifiedRequestBody = PlaceSearchRequest(
            keys: requestBody.keys,
            openNow: requestBody.openNow,
            priceLevels: requestBody.priceLevels,
            radius: requestBody.radius,
            location: requestBody.location,
            bypassCache: true,  // Always force bypass cache for filter requests
            maxResultCount: requestBody.maxResultCount,
            minimumRating: requestBody.minimumRating
        )
        
        do {
            // Log the complete request body for debugging
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(modifiedRequestBody),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.notice("Full request body: \(jsonString)")
            }
            
            let response: PlacesResponse = try await networkService.post(
                endpoint: .placeSearch,
                body: modifiedRequestBody,
                queryItems: nil,
                authToken: nil
            )
            
            // Log the response details
            logger.notice("Received \(response.results.count) places from API, cacheHit: \(response.cacheHit)")
            
            // Log the first few places to verify what we're getting
            if !response.results.isEmpty {
                let samplePlaces = response.results.prefix(min(3, response.results.count))
                logger.notice("Sample places received: \(samplePlaces.map { $0.id })")
            }
            
            // Cache the results
            placesCache[cacheKey] = (places: response.results, timestamp: Date())
            logger.notice("Cached \(response.results.count) filtered places")
            
            return response
        } catch {
            logger.error("Error fetching places with filters: \(error.localizedDescription)")
            throw mapToPlacesServiceError(error)
        }
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
