import Foundation
import MapKit
import os

/// Service for interacting with our backend API
class BackendService: GooglePlacesServiceProtocol {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "BackendService")
    
    // Dependencies
    private let networkManager: NetworkRequestManager
    private let taskManager: TaskManager
    private let throttler: RequestThrottler
    private let placesHandler: PlacesRequestHandler
    private let placeDetailsHandler: PlaceDetailsRequestHandler
    private let cache: NetworkCache
    
    // MARK: - Initialization
    
    init() {
        logger.notice("BackendService initialized, using production API")
        
        // Initialize dependencies
        self.networkManager = NetworkRequestManager()
        self.taskManager = TaskManager()
        self.throttler = RequestThrottler(minimumInterval: 2.0)
        self.cache = NetworkCache.shared
        
        // Get the base URL
        let baseURL = Configuration.backendURL
        
        // Initialize handlers
        self.placesHandler = PlacesRequestHandler(
            networkManager: networkManager,
            taskManager: taskManager,
            throttler: throttler,
            cache: cache,
            baseURL: baseURL
        )
        
        self.placeDetailsHandler = PlaceDetailsRequestHandler(
            networkManager: networkManager,
            taskManager: taskManager,
            throttler: throttler,
            cache: cache,
            baseURL: baseURL
        )
        
        // Test the connection to the backend API
        testBackendConnection()
        
        // Log the base URL being used
        logger.notice("Using production URL: \(baseURL.absoluteString)")
    }
    
    // Test the connection to the backend API
    private func testBackendConnection() {
        Task {
            logger.notice("Testing connection to production backend API...")
            
            // Try the production URL
            if await networkManager.testURL(baseURL: Configuration.backendURL) {
                logger.notice("✅ Successfully connected to production backend URL")
                return
            }
            
            // If the URL fails, log an error
            logger.error("❌ Failed to connect to production backend. Please check your internet connection.")
        }
    }
    
    // MARK: - GooglePlacesServiceProtocol Implementation
    
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        placesHandler.fetchPlaces(
            center: center,
            region: region,
            categories: categories,
            showOpenNowOnly: showOpenNowOnly,
            completion: completion
        )
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        placeDetailsHandler.fetchPlaceDetails(placeId: placeId, completion: completion)
    }
    
    // MARK: - Async/Await API
    
    /// Async version of fetchPlaces that uses Swift's structured concurrency
    /// - Parameters:
    ///   - center: The center coordinate to search around
    ///   - region: Optional region to determine search radius
    ///   - categories: Categories to search for
    ///   - showOpenNowOnly: Whether to only show places that are open now
    /// - Returns: Array of places
    /// - Throws: NetworkError if the request fails
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool
    ) async throws -> [Place] {
        return try await placesHandler.fetchPlaces(
            center: center,
            region: region,
            categories: categories,
            showOpenNowOnly: showOpenNowOnly
        )
    }
    
    /// Async version of fetchPlaceDetails that uses Swift's structured concurrency
    /// - Parameter placeId: The ID of the place to fetch details for
    /// - Returns: The place details
    /// - Throws: NetworkError if the request fails
    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        return try await placeDetailsHandler.fetchPlaceDetails(placeId: placeId)
    }
    
    // MARK: - Task Management
    
    func cancelAllRequests() {
        cancelPlacesRequests()
        cancelPlaceDetailsRequests()
        networkManager.cancelAllSessionTasks()
        throttler.reset()
    }
    
    func cancelPlacesRequests() {
        taskManager.cancelTask(forKey: "places")
    }
    
    func cancelPlaceDetailsRequests() {
        taskManager.cancelTask(forKey: "placeDetails")
    }
    
    // MARK: - Deinitialization
    
    deinit {
        cancelAllRequests()
        logger.debug("BackendService deinit called")
    }
} 
