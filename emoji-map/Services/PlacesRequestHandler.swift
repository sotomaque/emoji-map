import Foundation
import MapKit
import os.log

/// Handles requests for fetching places
class PlacesRequestHandler {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlacesRequestHandler")
    
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
        
        logger.debug("PlacesRequestHandler initialized")
    }
    
    // MARK: - Places Request
    
    /// Fetch places from the API
    /// - Parameters:
    ///   - center: The center coordinate for the search
    ///   - region: Optional region to determine search radius
    ///   - categories: Categories to search for
    ///   - showOpenNowOnly: Whether to only show places that are open now
    ///   - completion: Completion handler with the result
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [(emoji: String, name: String, type: String)],
        showOpenNowOnly: Bool,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        // Generate cache key for this request
        let cacheKey = cache.generatePlacesCacheKey(center: center, categories: categories, showOpenNowOnly: showOpenNowOnly)
        
        // Check if we have cached results
        if let cachedPlaces = cache.retrievePlaces(forKey: cacheKey) {
            logger.info("Using cached places for key: \(cacheKey)")
            completion(.success(cachedPlaces))
            return
        }
        
        // Check if we can make a request now
        if !throttler.canMakeRequest() {
            // Wait and retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.fetchPlaces(
                    center: center,
                    region: region,
                    categories: categories,
                    showOpenNowOnly: showOpenNowOnly,
                    completion: completion
                )
            }
            return
        }
        
        // Mark that a request is starting
        throttler.requestStarting()
        
        logger.notice("Using backend API for fetchPlaces")
        
        // Cancel any existing places request
        taskManager.cancelTask(forKey: "places")
        
        // Calculate radius based on the region if provided, otherwise use default from Configuration
        let radius: Int
        if let region = region {
            // Calculate the distance from center to edge of the visible region
            let centerLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let edgeLocation = CLLocation(
                latitude: region.center.latitude + region.span.latitudeDelta/2,
                longitude: region.center.longitude + region.span.longitudeDelta/2
            )
            
            // Get the distance in meters and round to nearest 100m
            let distanceInMeters = Int(centerLocation.distance(from: edgeLocation))
            
            // Ensure radius is between min and max values from Configuration
            radius = min(max(distanceInMeters, Configuration.minSearchRadius), Configuration.maxSearchRadius)
            
            // Log the calculated radius for debugging
            logger.debug("Calculated search radius: \(radius)m based on map region")
        } else {
            // Default radius from Configuration
            radius = Configuration.defaultSearchRadius
            logger.debug("Using default search radius: \(radius)m")
        }
        
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
            
            // Create a reference to the logger for use in the actor
            let actorLogger = self.logger
            
            // Use an actor to ensure thread-safe access to shared state
            actor FetchState {
                var allPlaces: [Place] = []
                var errors: [NetworkError] = []
                var completedRequests: Int = 0
                var totalRequests: Int = 0
                private let logger: Logger
                
                init(logger: Logger) {
                    self.logger = logger
                }
                
                func addPlaces(_ places: [Place]) {
                    allPlaces.append(contentsOf: places)
                    completedRequests += 1
                }
                
                func addError(_ error: NetworkError) {
                    errors.append(error)
                    completedRequests += 1
                }
                
                func setTotalRequests(_ count: Int) {
                    totalRequests = count
                }
                
                func isComplete() -> Bool {
                    return completedRequests >= totalRequests
                }
                
                // Accessor methods for actor properties
                func getCompletedRequests() -> Int {
                    return completedRequests
                }
                
                func getTotalRequests() -> Int {
                    return totalRequests
                }
                
                func getResult() -> Result<[Place], NetworkError> {
                    if !errors.isEmpty && allPlaces.isEmpty {
                        // Return the first error if any occurred and we have no places
                        return .failure(errors.first!)
                    } else if allPlaces.isEmpty {
                        // If no places were found, return a specific error
                        return .failure(.noResults(placeType: "places"))
                    } else if !errors.isEmpty {
                        // If we have some places but also errors, return a partial results message
                        logger.notice("Returning \(self.allPlaces.count) places despite some errors")
                        return .success(allPlaces) // Still return the places we found
                    } else {
                        logger.notice("Returning \(self.allPlaces.count) places with no errors")
                        return .success(allPlaces)
                    }
                }
                
                // Debug method to print current state
                func logState() {
                    logger.notice("FetchState: \(self.completedRequests)/\(self.totalRequests) requests completed, \(self.allPlaces.count) places, \(self.errors.count) errors")
                }
            }
            
            let fetchState = FetchState(logger: actorLogger)
            
            // Group categories by type to reduce API calls
            let categoriesByType = Dictionary(grouping: categories) { $0.type }
            
            // Set the total number of requests
            await fetchState.setTotalRequests(categoriesByType.count)
            
            await withTaskGroup(of: Void.self) { group in
                for (placeType, categoriesOfType) in categoriesByType {
                    group.addTask {
                        // Check if task was cancelled
                        if Task.isCancelled {
                            await fetchState.addError(.requestCancelled)
                            return
                        }
                        
                        // Create the URL for our backend API
                        let nearbyEndpoint = self.networkManager.createURLWithPath(baseURL: self.baseURL, pathComponents: ["api", "places", "nearby"])
                        let location = "\(center.latitude),\(center.longitude)"
                        
                        // Log the endpoint we're calling
                        self.logger.notice("Calling backend API: \(nearbyEndpoint.absoluteString)")
                        
                        // Create a comma-separated list of keywords for this type
                        let keywordList = categoriesOfType.map { $0.name }.joined(separator: ",")
                        
                        // Log the keywords being sent
                        self.logger.notice("Sending keywords for type \(placeType): \(keywordList)")
                        
                        // Create properly encoded URL using helper method
                        let parameters: [String: String] = [
                            "location": location,
                            "radius": "\(radius)",
                            "type": placeType,  // This is for the Google Places API
                            "keywords": keywordList, // Changed from "category" to "keywords" to match new backend expectation
                            "open_now": showOpenNowOnly ? "true" : "false"
                        ]
                        
                        // Log the parameters
                        self.logger.notice("With parameters: \(parameters)")
                        
                        guard let url = self.networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters) else {
                            self.logger.error("Failed to create URL for nearby places request")
                            await fetchState.addError(.invalidURL)
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
                            
                            // Note: We can't remove the task from tracking here because we can't reference it
                            // without creating a circular reference. The URLSession will handle cleanup.
                            
                            // Check for cancellation or errors
                            if let error = error {
                                let networkError = self.networkManager.convertToNetworkError(error)
                                Task { await fetchState.addError(networkError) }
                                self.logger.error("Network error: \(error.localizedDescription)")
                                return
                            }
                            
                            // Check for valid data
                            guard let data = data else {
                                Task { await fetchState.addError(.noData) }
                                self.logger.error("No data received from server")
                                return
                            }
                            
                            // Check HTTP response
                            guard let httpResponse = response as? HTTPURLResponse else {
                                Task { await fetchState.addError(.networkConnectionError) }
                                self.logger.error("Network connection error: Response is not an HTTP response")
                                return
                            }
                            
                            // Log the HTTP status code
                            self.logger.notice("HTTP status code: \(httpResponse.statusCode)")
                            
                            // Check for HTTP errors
                            if httpResponse.statusCode != 200 {
                                let networkError = self.networkManager.handleServerError(statusCode: httpResponse.statusCode, data: data)
                                Task { await fetchState.addError(networkError) }
                                return
                            }
                            
                            do {
                                // Parse the response from our backend
                                struct BackendPlacesResponse: Decodable {
                                    let places: [Place]
                                }
                                
                                let response = try JSONDecoder().decode(BackendPlacesResponse.self, from: data)
                                
                                // Check if we got any places
                                if response.places.isEmpty {
                                    self.logger.notice("No places found for type: \(placeType)")
                                    // Just mark as complete, don't add an error
                                    Task { 
                                        await fetchState.addPlaces([])
                                        await fetchState.logState()
                                    }
                                } else {
                                    // Add the places to our results
                                    self.logger.notice("Found \(response.places.count) places for type: \(placeType)")
                                    
                                    // Log the first place to help diagnose issues
                                    if let firstPlace = response.places.first {
                                        self.logger.notice("First place: id=\(firstPlace.placeId), name=\(firstPlace.name), category=\(firstPlace.category), coordinates=(\(firstPlace.coordinate.latitude), \(firstPlace.coordinate.longitude))")
                                    }
                                    
                                    // Ensure each place has the correct category set
                                    var placesWithCategory: [Place] = []
                                    for place in response.places {
                                        // Check if the place already has a valid category that matches one of our known categories
                                        let categoryNames = categoriesOfType.map { $0.name }
                                        
                                        if !place.category.isEmpty && categoryNames.contains(place.category) {
                                            // Category is already valid, add the place as is
                                            self.logger.notice("Place \(place.name) has valid category: \(place.category)")
                                            placesWithCategory.append(place)
                                        } else if !place.category.isEmpty {
                                            // The place has a category, but it's not in our list of categories for this type
                                            // This can happen when the backend assigns a category from a different type
                                            // Let's keep the category as is, since it's likely a valid category from another type
                                            self.logger.notice("Place \(place.name) has category \(place.category) which is not in the current type's categories")
                                            placesWithCategory.append(place)
                                        } else {
                                            // If the category is empty, use the first category name from the current type
                                            let categoryName = categoriesOfType.first?.name ?? placeType
                                            
                                            // Create a new place with the updated category
                                            let updatedPlace = Place(
                                                placeId: place.placeId,
                                                name: place.name,
                                                coordinate: place.coordinate,
                                                category: categoryName,
                                                description: place.description,
                                                priceLevel: place.priceLevel,
                                                openNow: place.openNow,
                                                rating: place.rating
                                            )
                                            
                                            // Log the category update
                                            self.logger.notice("Updated category for place \(place.name) from empty to '\(categoryName)'")
                                            
                                            // Add the updated place to the list
                                            placesWithCategory.append(updatedPlace)
                                        }
                                    }
                                    
                                    // Log the number of places after category update
                                    self.logger.notice("Processed \(placesWithCategory.count) places with updated categories for type: \(placeType)")
                                    
                                    Task { 
                                        await fetchState.addPlaces(placesWithCategory)
                                        await fetchState.logState()
                                    }
                                }
                                
                            } catch {
                                Task { await fetchState.addError(.decodingError) }
                                self.logger.error("Error decoding places response: \(error.localizedDescription)")
                            }
                        }
                        
                        // Create the task with the completion handler
                        let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
                        
                        // Add task to our tracking list
                        self.networkManager.addSessionTask(task)
                        
                        // Start the request
                        task.resume()
                    }
                }
            }
            
            // Wait for all requests to complete or timeout
            for _ in 0..<10 { // Check for 10 seconds max
                let isComplete = await fetchState.isComplete()
                if isComplete {
//                    logger.notice("All \(await fetchState.getCompletedRequests()) requests completed after \(i) seconds")
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
//                logger.notice("Waiting for requests to complete: \(await fetchState.getCompletedRequests())/\(await fetchState.getTotalRequests())")
            }
            
            // Log the state before getting the result
            await fetchState.logState()
            
            // Get the final result
            let result = await fetchState.getResult()
            
            // Log the result
            switch result {
            case .success(let places):
                logger.notice("Successfully fetched \(places.count) places")
                
                // Cache successful results
                if !places.isEmpty {
                    self.cache.storePlaces(places, forKey: cacheKey)
                    logger.notice("Cached \(places.count) places with key: \(cacheKey)")
                }
            case .failure(let error):
                logger.error("Failed to fetch places: \(error.localizedDescription)")
            }
            
            // Return the result on the main thread
            let logger = self.logger // Capture logger locally
            DispatchQueue.main.async {
                logger.notice("Returning result to caller")
                completion(result)
            }
        }
        
        // Assign the task to our property
        taskManager.setTask(newTask, forKey: "places")
    }
} 
