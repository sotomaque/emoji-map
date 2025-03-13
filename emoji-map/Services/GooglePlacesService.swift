//
//  GooglePlacesService.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//


import Foundation
import MapKit
import os

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
    case noResults(placeType: String)
    case requestTimeout
    case partialResults(message: String)
    
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
        case .noResults(let placeType):
            return "No results found for \(placeType)"
        case .requestTimeout:
            return "Request timed out. Please try again later."
        case .partialResults(let message):
            return message
        }
    }
    
    var shouldShowAlert: Bool {
        switch self {
        case .requestCancelled:
            return false
        case .requestTimeout:
            return true
        case .partialResults:
            return false
        default:
            return true
        }
    }
}

protocol GooglePlacesServiceProtocol: AnyObject {
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    )
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void)
    
    func cancelAllRequests()
    func cancelPlacesRequests()
    func cancelPlaceDetailsRequests()
    
    // Async/await versions
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool
    ) async throws -> [Place]
    
    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails
}

/// @deprecated This class is deprecated and should not be used.
/// Use BackendService instead which communicates with our backend API.
@available(*, deprecated, message: "This class is deprecated. Use BackendService instead.")
class GooglePlacesService: GooglePlacesServiceProtocol {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "GooglePlacesService")
    
    // Initializer
    init() {
        logger.error("⚠️ GooglePlacesService is deprecated and should not be used")
        logger.error("⚠️ Please use BackendService instead")
        
        // Log a stack trace to help identify where this is being used
        let stackSymbols = Thread.callStackSymbols
        logger.error("Stack trace: \(stackSymbols)")
    }
    
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool = false,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        logger.error("⚠️ GooglePlacesService.fetchPlaces called but this class is deprecated")
        completion(.failure(.apiError(message: "GooglePlacesService is deprecated. Use BackendService instead.")))
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        logger.error("⚠️ GooglePlacesService.fetchPlaceDetails called but this class is deprecated")
        completion(.failure(.apiError(message: "GooglePlacesService is deprecated. Use BackendService instead.")))
    }
    
    func cancelAllRequests() {
        logger.error("⚠️ GooglePlacesService.cancelAllRequests called but this class is deprecated")
    }
    
    func cancelPlacesRequests() {
        logger.error("⚠️ GooglePlacesService.cancelPlacesRequests called but this class is deprecated")
    }
    
    func cancelPlaceDetailsRequests() {
        logger.error("⚠️ GooglePlacesService.cancelPlaceDetailsRequests called but this class is deprecated")
    }
    
    deinit {
        logger.debug("GooglePlacesService deinit called")
    }
    
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool
    ) async throws -> [Place] {
        // Implementation of the async version of fetchPlaces
        throw NetworkError.apiError(message: "GooglePlacesService is deprecated. Use BackendService instead.")
    }
    
    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        // Implementation of the async version of fetchPlaceDetails
        throw NetworkError.apiError(message: "GooglePlacesService is deprecated. Use BackendService instead.")
    }
}
