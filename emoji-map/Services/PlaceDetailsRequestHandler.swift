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
            logger.notice("Request completed for place ID: \(placeId)")
        }
        
        logger.notice("Starting fetchPlaceDetailsAsync for place ID: \(placeId)")
        
        // Create the URL for our backend API - UPDATED to use correct endpoint format
        let detailsEndpoint = networkManager.createURLWithPath(baseURL: baseURL, pathComponents: ["api", "places", "details"])
        
        // Log the endpoint we're calling
        logger.notice("Calling backend API: \(detailsEndpoint.absoluteString)")
        
        // Create properly encoded URL using helper method
        let parameters = ["id": placeId]
        
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
        request.timeoutInterval = 10.0 // Reduced from 15 to 10 seconds
        
        // Use Swift's async/await URLSession API
        do {
            logger.notice("Starting network request for place ID: \(placeId)")
            
            // Create a task that will automatically timeout after 15 seconds (reduced from 20)
            let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                // Add the network request task
                group.addTask {
                    self.logger.notice("Network request task started for place ID: \(placeId)")
                    let (data, response) = try await self.networkManager.session.data(for: request)
                    self.logger.notice("Network request task completed for place ID: \(placeId)")
                    return (data, response)
                }
                
                // Add a timeout task
                group.addTask {
                    self.logger.notice("Timeout task started for place ID: \(placeId)")
                    try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds (reduced from 20)
                    self.logger.notice("Timeout reached for place ID: \(placeId)")
                    throw NetworkError.requestTimeout
                }
                
                // Return the first completed task result or throw its error
                logger.notice("Waiting for first task to complete for place ID: \(placeId)")
                let result = try await group.next()!
                logger.notice("Task completed for place ID: \(placeId)")
                
                // Cancel any remaining tasks
                group.cancelAll()
                
                return result
            }
            
            logger.notice("Network request completed for place ID: \(placeId)")
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Network connection error: Response is not an HTTP response")
                throw NetworkError.networkConnectionError
            }
            
            // Log the HTTP status code
            logger.notice("HTTP status code: \(httpResponse.statusCode) for place ID: \(placeId)")
            
            // Check for HTTP errors
            if httpResponse.statusCode != 200 {
                let networkError = networkManager.handleServerError(statusCode: httpResponse.statusCode, data: data)
                throw networkError
            }
            
            // Log data size
            logger.notice("Received \(data.count) bytes of data for place ID: \(placeId)")
            
            // Log the raw response data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.notice("Raw API response: \(jsonString.prefix(200))...") // Log just the beginning to avoid huge logs
            }
            
            // Start decoding
            logger.notice("Starting JSON decoding for place ID: \(placeId)")
            
            // Define new response structure to match the API
            struct NewAPIResponse: Decodable {
                let data: PlaceDetailsData
                let cacheHit: Bool
                let count: Int
            }
            
            struct PlaceDetailsData: Decodable {
                let name: String
                let reviews: [ReviewData]?
                let rating: Double?
                let priceLevel: Int?
                let userRatingCount: Int?
                let openNow: Bool?
                let displayName: String?
                let primaryTypeDisplayName: String?
                let takeout: Bool?
                let delivery: Bool?
                let dineIn: Bool?
                let editorialSummary: String?
                let outdoorSeating: Bool?
                let liveMusic: Bool?
                let menuForChildren: Bool?
                let servesDessert: Bool?
                let servesCoffee: Bool?
                let goodForChildren: Bool?
                let goodForGroups: Bool?
                let allowsDogs: Bool?
                let restroom: Bool?
                let paymentOptions: PaymentOptions?
                let generativeSummary: String?
                let isFree: Bool?
            }
            
            struct ReviewData: Decodable {
                let name: String
                let relativePublishTimeDescription: String
                let rating: Int
                let text: TextData
                let authorAttribution: AuthorData
                let publishTime: String
            }
            
            struct TextData: Decodable {
                let text: String
                let languageCode: String
            }
            
            struct AuthorData: Decodable {
                let displayName: String
                let uri: String
                let photoUri: String
            }
            
            struct PaymentOptions: Decodable {
                let acceptsCreditCards: Bool?
                let acceptsDebitCards: Bool?
                let acceptsCashOnly: Bool?
            }
            
            do {
                let decoder = JSONDecoder()
                logger.notice("Created JSONDecoder for place ID: \(placeId)")
                
                let startTime = Date()
                let response = try decoder.decode(NewAPIResponse.self, from: data)
                let decodingTime = Date().timeIntervalSince(startTime)
                logger.notice("JSON decoding completed in \(decodingTime) seconds for place ID: \(placeId)")
                
                // Log success and detailed response information
                logger.notice("Successfully fetched details for place ID: \(placeId)")
                
                let placeName = response.data.displayName ?? response.data.primaryTypeDisplayName ?? "No Display Name Found"
                
                // Log key fields from the response
                logger.notice("Computed Place Name: \(placeName)")
                logger.notice("Display name: \(response.data.displayName ?? "NO DISPLAY NAME FOUND")")
                logger.notice("Primary Type name: \(response.data.primaryTypeDisplayName ?? "NO PRIMARY TYPE FOUND")")
                logger.notice("Original name field: \(response.data.name)")
                logger.notice("Display name: \(response.data.displayName ?? "Not provided")")
                logger.notice("Primary type: \(response.data.primaryTypeDisplayName ?? "Unknown")")
                logger.notice("Rating: \(response.data.rating ?? 0.0)")
                logger.notice("Price level: \(response.data.priceLevel ?? 0)")
                logger.notice("User rating count: \(response.data.userRatingCount ?? 0)")
                logger.notice("Open now: \(response.data.openNow ?? false)")
                logger.notice("Generative summary: \(response.data.generativeSummary ?? "None")")
                
                // Log amenities
                let amenities = [
                    "Takeout": response.data.takeout,
                    "Delivery": response.data.delivery,
                    "Dine-in": response.data.dineIn,
                    "Outdoor seating": response.data.outdoorSeating,
                    "Live music": response.data.liveMusic,
                    "Menu for children": response.data.menuForChildren,
                    "Serves dessert": response.data.servesDessert,
                    "Serves coffee": response.data.servesCoffee,
                    "Good for children": response.data.goodForChildren,
                    "Good for groups": response.data.goodForGroups,
                    "Allows dogs": response.data.allowsDogs,
                    "Restroom": response.data.restroom
                ]
                
                let availableAmenities = amenities.compactMap { (key, value) -> String? in
                    if let value = value, value {
                        return key
                    }
                    return nil
                }
                
                logger.notice("Available amenities: \(availableAmenities.joined(separator: ", "))")
                
                // Log payment options
                if let paymentOptions = response.data.paymentOptions {
                    let options = [
                        "Accepts credit cards": paymentOptions.acceptsCreditCards,
                        "Accepts debit cards": paymentOptions.acceptsDebitCards,
                        "Cash only": paymentOptions.acceptsCashOnly
                    ]
                    
                    let availableOptions = options.compactMap { (key, value) -> String? in
                        if let value = value, value {
                            return key
                        }
                        return nil
                    }
                    
                    logger.notice("Payment options: \(availableOptions.joined(separator: ", "))")
                }
                
                // Log reviews
                if let reviews = response.data.reviews {
                    logger.notice("Number of reviews: \(reviews.count)")
                    
                    // Log details of the first review
                    if let firstReview = reviews.first {
                        logger.notice("First review - Author: \(firstReview.authorAttribution.displayName)")
                        logger.notice("First review - Rating: \(firstReview.rating)")
                        logger.notice("First review - Time: \(firstReview.relativePublishTimeDescription)")
                        logger.notice("First review - Text: \(firstReview.text.text)")
                    }
                } else {
                    logger.notice("No reviews available")
                }
                
                // Convert the new response format to our PlaceDetails model
                var photos: [String] = []
                // Note: The new API doesn't seem to include photos in the sample response
                // We'll need to add photo handling when available
                
                // Convert reviews to our expected format
                var reviews: [(String, String, Int, String)] = []
                if let apiReviews = response.data.reviews {
                    reviews = apiReviews.map { review in
                        (
                            review.authorAttribution.displayName,
                            review.text.text,
                            review.rating,
                            review.relativePublishTimeDescription
                        )
                    }
                    
                    // Log the first review to verify the data
                    if let firstReview = reviews.first {
                        logger.notice("First review (converted): \(firstReview.0) - \(firstReview.3)")
                    }
                }
                
                // Create a PlaceDetails object from the response with all the new fields
                logger.notice("Creating PlaceDetails object for place ID: \(placeId)")
                let placeDetails = PlaceDetails(
                    photos: photos,
                    reviews: reviews,
                    name: placeName,
                    rating: response.data.rating,
                    priceLevel: response.data.priceLevel,
                    userRatingCount: response.data.userRatingCount,
                    openNow: response.data.openNow,
                    primaryTypeDisplayName: response.data.primaryTypeDisplayName,
                    generativeSummary: response.data.generativeSummary,
                    takeout: response.data.takeout,
                    delivery: response.data.delivery,
                    dineIn: response.data.dineIn,
                    outdoorSeating: response.data.outdoorSeating,
                    liveMusic: response.data.liveMusic,
                    menuForChildren: response.data.menuForChildren,
                    servesDessert: response.data.servesDessert,
                    servesCoffee: response.data.servesCoffee,
                    goodForChildren: response.data.goodForChildren,
                    goodForGroups: response.data.goodForGroups,
                    allowsDogs: response.data.allowsDogs,
                    restroom: response.data.restroom,
                    acceptsCreditCards: response.data.paymentOptions?.acceptsCreditCards,
                    acceptsDebitCards: response.data.paymentOptions?.acceptsDebitCards,
                    acceptsCashOnly: response.data.paymentOptions?.acceptsCashOnly
                )
                
                // Log the created PlaceDetails object
                logger.notice("Created PlaceDetails object with name: \(placeDetails.name ?? "Unknown") and \(placeDetails.reviews.count) reviews")
                
                // Cache the result
                logger.notice("Caching PlaceDetails for place ID: \(placeId)")
                cache.storePlaceDetails(placeDetails, forPlaceId: placeId)
                
                // Return the result
                logger.notice("Returning PlaceDetails for place ID: \(placeId)")
                return placeDetails
            } catch {
                logger.error("Error decoding place details response: \(error.localizedDescription)")
                logger.error("Decoding error details: \(error)")
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
