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
        let newTask = Task<Void, Never> { [weak self] in
            guard let self = self else {
                completion(.failure(.requestCancelled))
                return
            }
            
            // Create a timeout task
            let timeoutTask = self.networkManager.createTimeoutTask(seconds: 20.0) { [weak self] in
                self?.throttler.requestCompleted()
                completion(.failure(.requestTimeout))
            }
            
            // Ensure we reset the in-progress flag and cancel the timeout task when we're done
            defer {
                timeoutTask.cancel()
                self.throttler.requestCompleted()
            }
            
            // Create the URL for our backend API
            let detailsEndpoint = self.networkManager.createURLWithPath(baseURL: self.baseURL, pathComponents: ["api", "places", "details"])
            
            // Log the endpoint we're calling
            self.logger.notice("Calling backend API: \(detailsEndpoint.absoluteString)")
            
            // Create properly encoded URL using helper method
            let parameters = ["placeId": placeId]
            
            // Log the parameters
            self.logger.notice("With parameters: \(parameters)")
            
            guard let url = self.networkManager.createURL(baseURL: detailsEndpoint, parameters: parameters) else {
                self.logger.error("Failed to create URL for place details request")
                completion(.failure(.invalidURL))
                return
            }
            
            // Log the full URL
            self.logger.notice("Full URL: \(url.absoluteString)")
            
            // Create a URLRequest with the URL
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15.0 // 15 seconds timeout
            
            // Define the completion handler separately
            let completionHandler: @Sendable (Data?, URLResponse?, Error?) -> Void = { [weak self] data, response, error in
                guard let self = self else { return }
                
                // Reset the in-progress flag
                self.throttler.requestCompleted()
                
                // Note: We can't remove the task from tracking here because we can't reference it
                // without creating a circular reference. The URLSession will handle cleanup.
                
                // Check for cancellation or errors
                if let error = error {
                    let networkError = self.networkManager.convertToNetworkError(error)
                    completion(.failure(networkError))
                    self.logger.error("Network error: \(error.localizedDescription)")
                    return
                }
                
                // Check for valid data
                guard let data = data else {
                    self.logger.error("No data received from server")
                    completion(.failure(.noData))
                    return
                }
                
                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logger.error("Network connection error: Response is not an HTTP response")
                    completion(.failure(.networkConnectionError))
                    return
                }
                
                // Log the HTTP status code
                self.logger.notice("HTTP status code: \(httpResponse.statusCode)")
                
                // Check for HTTP errors
                if httpResponse.statusCode != 200 {
                    let networkError = self.networkManager.handleServerError(statusCode: httpResponse.statusCode, data: data)
                    completion(.failure(networkError))
                    return
                }
                
                do {
                    // Parse the response from our backend
                    struct BackendPlaceDetailsResponse: Decodable {
                        let placeDetails: PlaceDetails
                    }
                    
                    let response = try JSONDecoder().decode(BackendPlaceDetailsResponse.self, from: data)
                    
                    // Log success
                    self.logger.notice("Successfully fetched details for place ID: \(placeId)")

                    // Cache the result
                    self.cache.storePlaceDetails(response.placeDetails, forPlaceId: placeId)
                    
                    // Return the result
                    completion(.success(response.placeDetails))
                    
                } catch {
                    self.logger.error("Error decoding place details response: \(error.localizedDescription)")
                    completion(.failure(.decodingError))
                }
            }
            
            // Create the task with the completion handler
            let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
            
            // Add task to our tracking list
            self.networkManager.addSessionTask(task)
            
            // Start the request
            task.resume()
        }
        
        // Assign the task to our property
        taskManager.setTask(newTask, forKey: "placeDetails")
    }
} 