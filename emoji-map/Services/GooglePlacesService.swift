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
        }
    }
    
    var shouldShowAlert: Bool {
        switch self {
        case .requestCancelled:
            return false
        default:
            return true
        }
    }
}

protocol GooglePlacesServiceProtocol: AnyObject {
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        categories: [(emoji: String, name: String, type: String)],
        showOpenNowOnly: Bool,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    )
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void)
    
    func cancelAllRequests()
    func cancelPlacesRequests()
    func cancelPlaceDetailsRequests()
}

class GooglePlacesService: GooglePlacesServiceProtocol {
    private let apiKey = Configuration.googlePlacesAPIKey
    private let useMockData = Configuration.isUsingMockKey
    private let mockService = MockGooglePlacesService()
    
    // Cache instance
    private let cache = NetworkCache.shared
    
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "GooglePlacesService")
    
    // Serial queue for thread synchronization
    private let taskQueue = DispatchQueue(label: "com.emoji-map.taskQueue")
    
    // Task management for cancellation with thread-safe access
    private var _placesTask: Task<Void, Never>?
    private var placesTask: Task<Void, Never>? {
        get {
            taskQueue.sync {
                return _placesTask
            }
        }
        set {
            taskQueue.async {
                // Cancel existing task before assigning a new one
                if self._placesTask != nil && newValue != nil {
                    self._placesTask?.cancel()
                }
                self._placesTask = newValue
            }
        }
    }
    
    private var _placeDetailsTask: Task<Void, Never>?
    private var placeDetailsTask: Task<Void, Never>? {
        get {
            taskQueue.sync {
                return _placeDetailsTask
            }
        }
        set {
            taskQueue.async {
                // Cancel existing task before assigning a new one
                if self._placeDetailsTask != nil && newValue != nil {
                    self._placeDetailsTask?.cancel()
                }
                self._placeDetailsTask = newValue
            }
        }
    }
    
    // Track active URLSession tasks for proper cancellation
    private var activeURLSessionTasks: [URLSessionTask] = []
    private let sessionTasksLock = NSLock()
    
    private func addSessionTask(_ task: URLSessionTask) {
        sessionTasksLock.lock()
        defer { sessionTasksLock.unlock() }
        activeURLSessionTasks.append(task)
    }
    
    private func removeSessionTask(_ task: URLSessionTask) {
        sessionTasksLock.lock()
        defer { sessionTasksLock.unlock() }
        activeURLSessionTasks.removeAll { $0 === task }
    }
    
    private func cancelAllSessionTasks() {
        sessionTasksLock.lock()
        let tasks = activeURLSessionTasks
        sessionTasksLock.unlock()
        
        for task in tasks {
            task.cancel()
        }
        
        sessionTasksLock.lock()
        activeURLSessionTasks.removeAll()
        sessionTasksLock.unlock()
    }
    
    // Helper method to create properly encoded URLs
    private func createURL(baseURL: String, parameters: [String: String]) -> URL? {
        guard var urlComponents = URLComponents(string: baseURL) else {
            return nil
        }
        
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        return urlComponents.url
    }
    
    func fetchPlaces(
        center: CLLocationCoordinate2D,
        categories: [(emoji: String, name: String, type: String)],
        showOpenNowOnly: Bool = false,
        completion: @escaping (Result<[Place], NetworkError>) -> Void
    ) {
        // Cancel any existing places request
        cancelPlacesRequests()
        
        // If using mock key, use mock data instead of making real API calls
        if useMockData {
            mockService.fetchPlaces(center: center, categories: categories, showOpenNowOnly: showOpenNowOnly, completion: completion)
            return
        }
        
        // Generate cache key for this request
        let cacheKey = cache.generatePlacesCacheKey(center: center, categories: categories, showOpenNowOnly: showOpenNowOnly)
        
        // Check if we have cached results
        if let cachedPlaces = cache.retrievePlaces(forKey: cacheKey) {
            logger.info("Using cached places for key: \(cacheKey)")
            completion(.success(cachedPlaces))
            return
        }
        
        // Create a new task for this request
        placesTask = Task { [weak self] in
            guard let self = self else {
                completion(.failure(.requestCancelled))
                return
            }
            
            // Capture completion handler weakly to avoid retain cycles
            let weakCompletion: (Result<[Place], NetworkError>) -> Void = { [weak self] result in
                // Only call completion if self still exists
                guard self != nil else { return }
                completion(result)
            }
            
            // Use an actor to ensure thread-safe access to shared state
            actor FetchState {
                var allPlaces: [Place] = []
                var errors: [NetworkError] = []
                
                func addPlaces(_ places: [Place]) {
                    allPlaces.append(contentsOf: places)
                }
                
                func addError(_ error: NetworkError) {
                    errors.append(error)
                }
                
                func getResult() -> Result<[Place], NetworkError> {
                    if !errors.isEmpty {
                        // Return the first error if any occurred
                        return .failure(errors.first!)
                    } else {
                        return .success(allPlaces)
                    }
                }
            }
            
            let fetchState = FetchState()
            
            // Group categories by type to reduce API calls
            let categoriesByType = Dictionary(grouping: categories) { $0.type }
            
            await withTaskGroup(of: Void.self) { group in
                for (placeType, categoriesOfType) in categoriesByType {
                    group.addTask {
                        // Check if task was cancelled
                        if Task.isCancelled {
                            return
                        }
                        
                        let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
                        let location = "\(center.latitude),\(center.longitude)"
                        
                        // Create a comma-separated list of keywords for this type
                        let keywordList = categoriesOfType.map { $0.name }.joined(separator: ",")
                        
                        // Create properly encoded URL using helper method
                        let parameters: [String: String] = [
                            "location": location,
                            "radius": "5000", // 5km radius
                            "type": placeType,
                            "keyword": keywordList,
                            "key": self.apiKey,
                            "opennow": showOpenNowOnly ? "true" : nil // Add open now parameter if filter is enabled
                        ].compactMapValues { $0 } // Remove nil values
                        
                        guard let url = self.createURL(baseURL: baseURL, parameters: parameters) else {
                            await fetchState.addError(.invalidURL)
                            return
                        }
                        
                        do {
                            // Create and track the URLSession task
                            let urlSession = URLSession.shared
                            let task = urlSession.dataTask(with: url) { _, _, _ in }
                            self.addSessionTask(task)
                            
                            // Start the task and wait for completion
                            let (data, response) = try await withTaskCancellationHandler {
                                try await urlSession.data(from: url)
                            } onCancel: {
                                task.cancel()
                            }
                            
                            // Remove the task from tracking once completed
                            self.removeSessionTask(task)
                            
                            // Check HTTP response
                            guard let httpResponse = response as? HTTPURLResponse else {
                                await fetchState.addError(.networkConnectionError)
                                return
                            }
                            
                            // Check for HTTP errors
                            if httpResponse.statusCode != 200 {
                                await fetchState.addError(.serverError(statusCode: httpResponse.statusCode))
                                return
                            }
                            
                            do {
                                let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                                
                                // Check if API returned an error or zero results
                                if let status = response.status {
                                    if status == "ZERO_RESULTS" {
                                        // Handle zero results as a specific case
                                        await fetchState.addError(.noResults(placeType: placeType))
                                        return
                                    } else if status != "OK" {
                                        let errorMessage = response.error_message ?? "Unknown API error"
                                        await fetchState.addError(.apiError(message: "\(status): \(errorMessage)"))
                                        return
                                    }
                                }
                                
                                // Process results and assign to appropriate categories
                                for result in response.results {
                                    // Find the best matching category for this result
                                    let matchingCategories = categoriesOfType.filter { category in
                                        // Check if the place name or vicinity contains the category keyword
                                        let name = result.name.lowercased()
                                        let vicinity = result.vicinity.lowercased()
                                        let keyword = category.name.lowercased()
                                        
                                        return name.contains(keyword) || vicinity.contains(keyword)
                                    }
                                    
                                    // Use the first matching category or default to the first category of this type
                                    let category = matchingCategories.first?.name ?? categoriesOfType.first?.name ?? "Unknown"
                                    
                                    let place = Place(
                                        placeId: result.place_id, 
                                        name: result.name,
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: result.geometry.location.lat,
                                            longitude: result.geometry.location.lng
                                        ),
                                        category: category,
                                        description: result.vicinity,
                                        priceLevel: result.price_level,
                                        openNow: result.opening_hours?.open_now,
                                        rating: result.rating
                                    )
                                    
                                    await fetchState.addPlaces([place])
                                }
                            } catch {
                                await fetchState.addError(.decodingError)
                                print("Decoding error for \(placeType): \(error)")
                            }
                        } catch let urlError as URLError {
                            // Check if the error is due to cancellation
                            if urlError.code == .cancelled {
                                return
                            }
                            
                            // Handle specific URL session errors
                            switch urlError.code {
                            case .notConnectedToInternet, .networkConnectionLost:
                                await fetchState.addError(.networkConnectionError)
                            default:
                                await fetchState.addError(.unknownError(urlError))
                            }
                            print("Network error fetching \(placeType) places: \(urlError)")
                        } catch {
                            await fetchState.addError(.unknownError(error))
                            print("Unknown error fetching \(placeType) places: \(error)")
                        }
                    }
                }
            }
            
            // Check if task was cancelled before returning results
            if Task.isCancelled {
                weakCompletion(.failure(.requestCancelled))
                return
            }
            
            // Get the final result from our thread-safe state
            let result = await fetchState.getResult()
            
            // Apply any additional filtering if needed
            if case .success(var places) = result {
                // Apply open now filter if enabled (redundant if already filtered in API call)
                if showOpenNowOnly {
                    places = places.filter { $0.openNow == true }
                }
                
                // Cache the results before returning
                self.cache.storePlaces(places, forKey: cacheKey)
                
                weakCompletion(.success(places))
            } else {
                weakCompletion(result)
            }
        }
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (Result<PlaceDetails, NetworkError>) -> Void) {
        // If using mock key, use mock data instead of making real API calls
        if useMockData {
            mockService.fetchPlaceDetails(placeId: placeId, completion: completion)
            return
        }
        
        // Check if we have cached details for this place
        if let cachedDetails = cache.retrievePlaceDetails(forPlaceId: placeId) {
            logger.info("Using cached details for place ID: \(placeId)")
            completion(.success(cachedDetails))
            return
        }
        
        // Create a new task for this request
        placeDetailsTask = Task { [weak self] in
            guard let self = self else {
                completion(.failure(.requestCancelled))
                return
            }
            
            // Capture completion handler weakly to avoid retain cycles
            let weakCompletion: (Result<PlaceDetails, NetworkError>) -> Void = { [weak self] result in
                // Only call completion if self still exists
                guard self != nil else { return }
                completion(result)
            }
            
            let baseURL = "https://maps.googleapis.com/maps/api/place/details/json"
            
            // Create properly encoded URL using helper method
            let parameters: [String: String] = [
                "place_id": placeId,
                "fields": "name,photos,reviews",
                "key": apiKey
            ]
            
            guard let url = createURL(baseURL: baseURL, parameters: parameters) else {
                weakCompletion(.failure(.invalidURL))
                return
            }
            
            do {
                // Check if task was cancelled before making the request
                if Task.isCancelled {
                    weakCompletion(.failure(.requestCancelled))
                    return
                }
                
                // Create and track the URLSession task
                let urlSession = URLSession.shared
                let task = urlSession.dataTask(with: url) { _, _, _ in }
                self.addSessionTask(task)
                
                // Start the task and wait for completion
                let (data, response) = try await withTaskCancellationHandler {
                    try await urlSession.data(from: url)
                } onCancel: {
                    task.cancel()
                }
                
                // Remove the task from tracking once completed
                self.removeSessionTask(task)
                
                // Check if task was cancelled after receiving the response
                if Task.isCancelled {
                    weakCompletion(.failure(.requestCancelled))
                    return
                }
                
                // Check HTTP status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    weakCompletion(.failure(.unknownError(NSError(domain: "HTTPResponse", code: 0, userInfo: nil))))
                    return
                }
                
                // Handle HTTP errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    weakCompletion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                    return
                }
                
                // Check for empty data
                guard !data.isEmpty else {
                    weakCompletion(.failure(.noData))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
                    
                    // Check if API returned an error
                    if let status = response.status {
                        if status == "ZERO_RESULTS" {
                            // Handle zero results as a specific case
                            weakCompletion(.failure(.noResults(placeType: "details")))
                            return
                        } else if status != "OK" {
                            let errorMessage = response.error_message ?? "Unknown API error"
                            weakCompletion(.failure(.apiError(message: "\(status): \(errorMessage)")))
                            return
                        }
                    }
                    
                    // Create properly encoded photo URLs
                    let photos = response.result.photos?.compactMap { photo -> String? in
                        let photoParameters: [String: String] = [
                            "maxwidth": "400",
                            "photoreference": photo.photo_reference,
                            "key": self.apiKey
                        ]
                        return self.createURL(baseURL: "https://maps.googleapis.com/maps/api/place/photo", parameters: photoParameters)?.absoluteString
                    } ?? []
                    
                    let details = PlaceDetails(
                        photos: photos,
                        reviews: response.result.reviews?.map { ($0.author_name, $0.text, $0.rating) } ?? []
                    )
                    
                    // Cache the details before returning
                    self.cache.storePlaceDetails(details, forPlaceId: placeId)
                    
                    weakCompletion(.success(details))
                } catch {
                    weakCompletion(.failure(.decodingError))
                    print("Decoding error: \(error)")
                }
            } catch let urlError as URLError {
                // Check if the error is due to cancellation
                if urlError.code == .cancelled {
                    weakCompletion(.failure(.requestCancelled))
                    return
                }
                
                // Handle specific URL session errors
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    weakCompletion(.failure(.networkConnectionError))
                default:
                    weakCompletion(.failure(.unknownError(urlError)))
                }
                print("Network error fetching place details: \(urlError)")
            } catch {
                weakCompletion(.failure(.unknownError(error)))
                print("Unknown error fetching place details: \(error)")
            }
        }
    }
    
    func cancelAllRequests() {
        // Cancel all tasks
        cancelPlacesRequests()
        cancelPlaceDetailsRequests()
        
        // Cancel all URLSession tasks
        cancelAllSessionTasks()
        
        // Log for debugging
        print("All requests cancelled")
    }
    
    func cancelPlacesRequests() {
        // Use sync to ensure the task is cancelled before returning
        taskQueue.sync {
            // Cancel the task if it exists
            self._placesTask?.cancel()
            // Clear the reference
            self._placesTask = nil
        }
        
        // Log for debugging
        print("Places requests cancelled")
    }
    
    func cancelPlaceDetailsRequests() {
        // Use sync to ensure the task is cancelled before returning
        taskQueue.sync {
            // Cancel the task if it exists
            self._placeDetailsTask?.cancel()
            // Clear the reference
            self._placeDetailsTask = nil
        }
        
        // Log for debugging
        print("Place details requests cancelled")
    }
    
    deinit {
        // Log for debugging first, in case the other operations fail
        print("GooglePlacesService deinit called")
        
        // Cancel all tasks and requests
        cancelAllRequests()
        
        // Ensure all URLSession tasks are cancelled
        cancelAllSessionTasks()
        
        // Clear any references - use sync to ensure it completes before deinit finishes
        taskQueue.sync {
            self._placesTask = nil
            self._placeDetailsTask = nil
        }
    }
}
