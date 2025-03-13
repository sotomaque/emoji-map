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
    
    // MARK: - Helper Methods
    
    /// Helper function to log the structure of JSON data for debugging
    private func logJSONStructure(_ data: Data) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            logger.error("Failed to parse JSON data")
            return
        }
        
        func describeValue(_ value: Any, indent: String = "") -> String {
            if let dict = value as? [String: Any] {
                var result = "{\n"
                for (key, val) in dict {
                    result += "\(indent)  \"\(key)\": \(describeValue(val, indent: indent + "  ")),\n"
                }
                result += "\(indent)}"
                return result
            } else if let array = value as? [Any] {
                if array.isEmpty {
                    return "[]"
                }
                var result = "[\n"
                for (index, val) in array.enumerated() {
                    if index < 3 || index == array.count - 1 {
                        result += "\(indent)  \(describeValue(val, indent: indent + "  ")),\n"
                    } else if index == 3 {
                        result += "\(indent)  ... (\(array.count - 4) more items) ...\n"
                        break
                    }
                }
                result += "\(indent)]"
                return result
            } else if let string = value as? String {
                return "\"\(string.prefix(50))\(string.count > 50 ? "..." : "")\""
            } else {
                return "\(value)"
            }
        }
        
        logger.notice("JSON Structure: \(describeValue(jsonObject))")
    }
    
    /// Helper function to remove trailing commas from JSON data
    private func removeTrailingCommas(from data: Data) -> Data {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to convert JSON data to string")
            return data
        }
        
        // Log a sample of the original JSON for debugging
        let sampleLength = min(200, jsonString.count)
        let sample = String(jsonString.prefix(sampleLength))
        logger.notice("Original JSON sample: \(sample)\(jsonString.count > sampleLength ? "..." : "")")
        
        // Replace trailing commas in objects (e.g., "longitude": 117.43541,})
        let cleanedString = jsonString.replacingOccurrences(
            of: ",\\s*}",
            with: "}",
            options: .regularExpression
        ).replacingOccurrences(
            of: ",\\s*]",
            with: "]",
            options: .regularExpression
        )
        
        logger.notice("Cleaned JSON string to remove trailing commas")
        
        // Log if any changes were made
        if jsonString != cleanedString {
            logger.notice("JSON was modified to fix trailing commas")
            
            // Log a sample of the cleaned JSON
            let cleanedSample = String(cleanedString.prefix(sampleLength))
            logger.notice("Cleaned JSON sample: \(cleanedSample)\(cleanedString.count > sampleLength ? "..." : "")")
        } else {
            logger.notice("No trailing commas found in JSON")
        }
        
        guard let cleanedData = cleanedString.data(using: .utf8) else {
            logger.error("Failed to convert cleaned string back to data")
            return data
        }
        
        return cleanedData
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
        categories: [String]?,
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
        
        // Create a new task for this request
        let newTask = Task {
            do {
                let places = try await fetchPlacesAsync(
                    center: center,
                    region: region,
                    categories: categories,
                    showOpenNowOnly: showOpenNowOnly
                )
                
                // Cache the results
                if !places.isEmpty {
                    self.cache.storePlaces(places, forKey: cacheKey)
                }
                
                completion(.success(places))
            } catch let error as NetworkError {
                completion(.failure(error))
            } catch {
                completion(.failure(.unknownError(error)))
            }
        }
        
        // Store the task so we can cancel it if needed
        taskManager.setTask(newTask, forKey: "places")
    }
    
    /// Async version of fetchPlaces that uses Swift's structured concurrency
    /// - Parameters:
    ///   - center: The center coordinate to search around
    ///   - region: Optional region to determine search radius
    ///   - categories: Categories to search for
    ///   - showOpenNowOnly: Whether to only show places that are open now
    /// - Returns: Array of places
    /// - Throws: NetworkError if the request fails
    private func fetchPlacesAsync(
        center: CLLocationCoordinate2D,
        region: MKCoordinateRegion?,
        categories: [String]?,
        showOpenNowOnly: Bool
    ) async throws -> [Place] {
        // Ensure we reset the in-progress flag when we're done
        defer {
            throttler.requestCompleted()
        }
        
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
        
        // Create the URL for our backend API
        let nearbyEndpoint = networkManager.createURLWithPath(baseURL: baseURL, pathComponents: ["api", "places", "nearby"])
        let location = "\(center.latitude),\(center.longitude)"
        
        // Log the endpoint we're calling
        logger.notice("Calling backend API: \(nearbyEndpoint.absoluteString)")
        
        // Create parameters for the request
        var parameters: [String: String] = [
            "location": location,
            "open_now": showOpenNowOnly ? "true" : "false"
        ]
        
        // Log the parameters
        logger.notice("With parameters: \(parameters)")
        
        // Create URL components to manually add the keys parameter multiple times
        var components = URLComponents(url: nearbyEndpoint, resolvingAgainstBaseURL: true)
        
        // Start with the basic parameters
        var queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        // Only add category keys if categories is not nil and not empty
        if let categories = categories, !categories.isEmpty {
            // Get the keys for the categories
            let categoryKeys = categories.compactMap { emoji -> Int? in
                // Get the key for the emoji
                return CategoryMappings.getKeyForEmoji(emoji)
            }
            
            // Log the keys being sent
            logger.notice("Sending keys: \(categoryKeys)")
            
            // Add each key as a separate query parameter
            for key in categoryKeys {
                queryItems.append(URLQueryItem(name: "keys", value: "\(key)"))
            }
        } else {
            // Log that we're not sending any category keys (using all categories)
            logger.notice("No category keys specified - using all categories")
        }
        
        // Set the query items
        components?.queryItems = queryItems
        
        // Get the final URL
        guard let url = components?.url else {
            logger.error("Failed to create URL for nearby places request")
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
            
            // Log the raw response data as a string for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.notice("Raw response data: \(responseString)")
            } else {
                logger.error("Could not convert response data to string")
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
            struct BackendPlacesResponse: Decodable {
                let cacheHit: Bool
                let count: Int
                let data: [PlaceData]
                
                // Custom decoding to handle cacheHit as either Bool or Int
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    // Decode count and data normally
                    count = try container.decode(Int.self, forKey: .count)
                    data = try container.decode([PlaceData].self, forKey: .data)
                    
                    // Try to decode cacheHit as a Bool first
                    do {
                        cacheHit = try container.decode(Bool.self, forKey: .cacheHit)
                    } catch {
                        // If that fails, try to decode as an Int and convert to Bool
                        let intValue = try container.decode(Int.self, forKey: .cacheHit)
                        cacheHit = intValue != 0
                    }
                }
                
                enum CodingKeys: String, CodingKey {
                    case cacheHit, count, data
                }
            }
            
            struct PlaceData: Decodable {
                let id: String
                let emoji: String
                let location: LocationData
            }
            
            struct LocationData: Decodable {
                let latitude: Double
                let longitude: Double
            }
            
            // Log the data structure we're trying to decode
            logger.notice("Attempting to decode data as BackendPlacesResponse with data array")
            
            // Try to decode the JSON structure first to see what we're getting
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonDict = jsonObject as? [String: Any] {
                logger.notice("JSON structure keys: \(jsonDict.keys.joined(separator: ", "))")
                
                // Check if 'data' key exists and what type it is
                if let places = jsonDict["data"] {
                    logger.notice("'data' key exists with type: \(type(of: places))")
                    
                    // If it's an array, log the count and first item structure
                    if let placesArray = places as? [[String: Any]] {
                        logger.notice("'data' is an array with \(placesArray.count) items")
                        if let firstPlace = placesArray.first {
                            logger.notice("First place keys: \(firstPlace.keys.joined(separator: ", "))")
                        }
                    }
                } else {
                    logger.error("'data' key does not exist in response")
                }
            }
            
            // Create a custom decoder with more lenient options
            let decoder = JSONDecoder()
            // Try to handle the JSON with potential trailing commas
            let cleanedData = self.removeTrailingCommas(from: data)
            let placesResponse = try decoder.decode(BackendPlacesResponse.self, from: cleanedData)
            
            // Check if we got any places
            if placesResponse.data.isEmpty {
                logger.notice("No places found for type: \(categories?.first ?? "unknown")")
                return []
            }
            
            // Add the places to our results
            logger.notice("Found \(placesResponse.data.count) places for type: \(categories?.first ?? "unknown")")
            
            // Log the first place to help diagnose issues
            if let firstPlace = placesResponse.data.first {
                logger.notice("First place: id=\(firstPlace.id), emoji=\(firstPlace.emoji), coordinates=(\(firstPlace.location.latitude), \(firstPlace.location.longitude))")
            }
            
            // Convert the PlaceData objects to Place objects
            var places: [Place] = []
            for placeData in placesResponse.data {
                // Create a Place object from the PlaceData
                let place = Place(
                    placeId: placeData.id,
                    name: "", // We don't have this in the response
                    coordinate: CLLocationCoordinate2D(
                        latitude: placeData.location.latitude,
                        longitude: placeData.location.longitude
                    ),
                    category: placeData.emoji,
                    description: "", // We don't have this in the response
                    priceLevel: 0, // We don't have this in the response
                    openNow: false, // We don't have this in the response
                    rating: 0 // We don't have this in the response
                )
                
                places.append(place)
            }
            
            return places
            
        } catch let error as DecodingError {
            logger.error("Failed to decode places response: \(error.localizedDescription)")
            
            // Provide more detailed error information
            switch error {
            case .keyNotFound(let key, let context):
                logger.error("Key not found: \(key.stringValue), context: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                logger.error("Value not found: \(type), context: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                logger.error("Type mismatch: \(type), context: \(context.debugDescription)")
                
                // Try to extract the path to the problematic field
                if let codingPath = context.codingPath.last {
                    logger.error("Problem field: \(codingPath.stringValue)")
                }
            case .dataCorrupted(let context):
                logger.error("Data corrupted: \(context.debugDescription)")
            @unknown default:
                logger.error("Unknown decoding error: \(error)")
            }
            
            throw NetworkError.decodingError
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
    
    /// Provides an async/await interface for fetching places
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
        // Generate cache key for this request
        let cacheKey = cache.generatePlacesCacheKey(center: center, categories: categories, showOpenNowOnly: showOpenNowOnly)
        
        // Check if we have cached results
        if let cachedPlaces = cache.retrievePlaces(forKey: cacheKey) {
            logger.info("Using cached places for key: \(cacheKey)")
            return cachedPlaces
        }
        
        // Check if we can make a request now
        if !throttler.canMakeRequest() {
            // Wait and retry after a delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            return try await fetchPlaces(
                center: center,
                region: region,
                categories: categories,
                showOpenNowOnly: showOpenNowOnly
            )
        }
        
        // Cancel any existing places request
        taskManager.cancelTask(forKey: "places")
        
        // Mark that a request is starting
        throttler.requestStarting()
        
        logger.notice("Using backend API for fetchPlaces (async)")
        
        do {
            let places = try await fetchPlacesAsync(
                center: center,
                region: region,
                categories: categories,
                showOpenNowOnly: showOpenNowOnly
            )
            
            // Cache the results
            if !places.isEmpty {
                cache.storePlaces(places, forKey: cacheKey)
            }
            
            return places
        } catch {
            throttler.requestCompleted()
            throw error
        }
    }
} 
