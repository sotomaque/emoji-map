import Foundation
import os.log

/// Handles requests for fetching place details
class PlaceDetailsRequestHandler {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceDetailsRequestHandler")
    
    // Dependencies
    private let networkManager: NetworkRequestManager
    private let taskManager: TaskManager
    private let throttler: RequestThrottler
    private let cache: NetworkCache
    private let baseURL: URL
    
    // MARK: - Initialization
    
    init(
        networkManager: NetworkRequestManager,
        taskManager: TaskManager,
        throttler: RequestThrottler,
        cache: NetworkCache,
        baseURL: URL
    ) {
        self.networkManager = networkManager
        self.taskManager = taskManager
        self.throttler = throttler
        self.cache = cache
        self.baseURL = baseURL
        
        logger.debug("PlaceDetailsRequestHandler initialized")
    }
    
    // MARK: - Place Details Request
    
    /// Fetch place details from the API
    /// - Parameters:
    ///   - placeId: The ID of the place to fetch details for
    ///   - completion: Completion handler with the result
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        // Check if we have cached results
        if let cachedDetails = cache.retrievePlaceDetails(forPlaceId: placeId) {
            logger.info("Using cached place details for ID: \(placeId)")
            completion(.success(cachedDetails))
            return
        }
        
        // Check if we can make a request now
        if !throttler.canMakeRequest() {
            // Wait and retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.fetchPlaceDetails(placeId: placeId, completion: completion)
            }
            return
        }
        
        // Mark that a request is starting
        throttler.requestStarting()
        
        logger.notice("Using backend API for fetchPlaceDetails")
        
        // Cancel any existing place details request
        taskManager.cancelTask(forKey: "placeDetails")
        
        // Create a new task for this request
        let newTask = Task {
            do {
                let details = try await fetchPlaceDetailsAsync(placeId: placeId)
                completion(.success(details))
            } catch let error as NetworkError {
                completion(.failure(error))
            } catch {
                completion(.failure(.unknownError(error)))
            }
        }
        
        // Assign the task to our property
        taskManager.setTask(newTask, forKey: "placeDetails")
    }
    
    /// Async version of fetchPlaceDetails that uses Swift's structured concurrency
    /// - Parameter placeId: The ID of the place to fetch details for
    /// - Returns: The place details
    /// - Throws: NetworkError if the request fails
    private func fetchPlaceDetailsAsync(placeId: String) async throws -> PlaceDetails {
        // Ensure we reset the in-progress flag when we're done
        defer {
            throttler.requestCompleted()
        }
        
        // Create the URL for our backend API
        let detailsEndpoint = networkManager.createURLWithPath(baseURL: baseURL, pathComponents: ["api", "places", "details"])
        
        // Log the endpoint we're calling
        logger.notice("Calling backend API: \(detailsEndpoint.absoluteString)")
        
        // Create properly encoded URL using helper method
        let parameters = ["placeId": placeId]
        
        // Log the parameters
        logger.notice("With parameters: \(parameters)")
        
        guard let url = networkManager.createURL(baseURL: detailsEndpoint, parameters: parameters) else {
            logger.error("Failed to create URL for place details request")
            throw NetworkError.invalidURL
        }
        
        // Log the full URL
        logger.notice("Full URL: \(url.absoluteString)")
        
        // Create a URLRequest with the URL
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0 // 15 seconds timeout
        
        // Use Swift's async/await URLSession API
        do {
            // Create a task that will automatically timeout after 20 seconds
            let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                // Add the network request task
                group.addTask {
                    let (data, response) = try await self.networkManager.session.data(for: request)
                    return (data, response)
                }
                
                // Add a timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
                    throw NetworkError.requestTimeout
                }
                
                // Return the first completed task result or throw its error
                return try await group.next()!
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Network connection error: Response is not an HTTP response")
                throw NetworkError.networkConnectionError
            }
            
            // Log the HTTP status code
            logger.notice("HTTP status code: \(httpResponse.statusCode)")
            
            // Check for HTTP errors
            if httpResponse.statusCode != 200 {
                let networkError = networkManager.handleServerError(statusCode: httpResponse.statusCode, data: data)
                throw networkError
            }
            
            // Parse the response from our backend
            struct BackendPlaceDetailsResponse: Decodable {
                let placeDetails: PlaceDetails
            }
            
            do {
                let response = try JSONDecoder().decode(BackendPlaceDetailsResponse.self, from: data)
                
                // Log success
                logger.notice("Successfully fetched details for place ID: \(placeId)")
                
                // Cache the result
                cache.storePlaceDetails(response.placeDetails, forPlaceId: placeId)
                
                // Return the result
                return response.placeDetails
            } catch {
                logger.error("Error decoding place details response: \(error.localizedDescription)")
                throw NetworkError.decodingError
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            if Task.isCancelled {
                throw NetworkError.requestCancelled
            }
            logger.error("Network error: \(error.localizedDescription)")
            throw NetworkError.unknownError(error)
        }
    }
    
    /// Provides an async/await interface for fetching place details
    /// - Parameter placeId: The ID of the place to fetch details for
    /// - Returns: The place details
    /// - Throws: NetworkError if the request fails
    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        // Check if we have cached results
        if let cachedDetails = cache.retrievePlaceDetails(forPlaceId: placeId) {
            logger.info("Using cached place details for ID: \(placeId)")
            return cachedDetails
        }
        
        // Check if we can make a request now
        if !throttler.canMakeRequest() {
            // Wait and retry after a delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            return try await fetchPlaceDetails(placeId: placeId)
        }
        
        // Cancel any existing place details request
        taskManager.cancelTask(forKey: "placeDetails")
        
        // Mark that a request is starting
        throttler.requestStarting()
        
        logger.notice("Using backend API for fetchPlaceDetails (async)")
        
        do {
            return try await fetchPlaceDetailsAsync(placeId: placeId)
        } catch {
            throttler.requestCompleted()
            throw error
        }
    }
} 