//
//  PlaceDetailViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/4/25.
//

import Foundation
import UIKit
import MapKit
import os
import Combine

// Thread-safe actor for managing shared state
@MainActor
class PlaceDetailViewModel: ObservableObject {
    @Published var photos: [String] = []
    @Published var reviews: [(String, String, Int)] = []
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showError = false
    @Published var distanceFromUser: Double? = nil
    
    // Flag to track if the view model has been properly initialized with a real MapViewModel
    private var isInitialized = false
    
    // Reference to the MapViewModel
    private var mapViewModel: MapViewModel
    
    // Current place ID
    var currentPlaceId: String?
    
    // Computed properties that delegate to MapViewModel
    var isFavorite: Bool {
        guard isInitialized, let placeId = currentPlaceId else { return false }
        return mapViewModel.isFavorite(placeId: placeId)
    }
    
    var userRating: Int {
        guard isInitialized, let placeId = currentPlaceId else { return 0 }
        return mapViewModel.getRating(for: placeId) ?? 0
    }
    
    // Computed property to convert tuple reviews to Review objects
    var reviewObjects: [Review] {
        return reviews.map { Review(authorName: $0.0, text: $0.1, rating: $0.2) }
    }
    
    // Computed property to format the distance in a user-friendly way
    var formattedDistance: String {
        guard isInitialized, let distance = distanceFromUser else { return "Distance unavailable" }
        return mapViewModel.preferences.formatDistance(distance)
    }
    
    // Make service a private variable instead of a constant so we can update it
    private var service: GooglePlacesServiceProtocol
    
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceDetailViewModel")
    
    // Cache instance
    private let cache = NetworkCache.shared
    
    // Default initializer that creates a dummy MapViewModel
    init() {
        // Create a dummy MapViewModel that will be replaced later
        self.mapViewModel = MapViewModel()
        self.isInitialized = false
        // Use the shared service from ServiceContainer
        self.service = ServiceContainer.shared.googlePlacesService
        
        // Log that we're using the default initializer
        logger.info("PlaceDetailViewModel initialized with default initializer (dummy MapViewModel)")
    }
    
    init(mapViewModel: MapViewModel, service: GooglePlacesServiceProtocol? = nil) {
        self.mapViewModel = mapViewModel
        self.isInitialized = true
        // Use the provided service or get the shared instance from ServiceContainer
        self.service = service ?? ServiceContainer.shared.googlePlacesService
        
        // Log that we're using the real initializer
        logger.info("PlaceDetailViewModel initialized with real MapViewModel")
    }
    
    // Method to update the service after initialization - no longer needed but kept for compatibility
    func updateService(_ newService: GooglePlacesServiceProtocol) {
        // Cancel any pending requests on the old service
        self.service.cancelPlaceDetailsRequests()
        // Update to the new service
        self.service = newService
    }
    
    // Calculate the distance from the user to the place
    func calculateDistanceFromUser(place: Place, userLocation: CLLocation?) {
        guard let userLocation = userLocation else {
            distanceFromUser = nil
            return
        }
        
        let placeLocation = CLLocation(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude
        )
        
        // Calculate the distance in meters
        distanceFromUser = userLocation.distance(from: placeLocation)
    }
    
    func fetchDetails(for place: Place) {
        // Set the current place ID first
        currentPlaceId = place.placeId
        
        // Only proceed with network requests if we need to fetch photos and reviews
        fetchNetworkDetails(for: place)
    }
    
    // Fetch details that require network requests
    private func fetchNetworkDetails(for place: Place) {
        // Use a task to delay showing the loading indicator
        let loadingTask = Task { @MainActor in
            // Wait a short delay before showing loading indicator
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            if !Task.isCancelled {
                isLoading = true
            }
        }
        
        error = nil
        showError = false
        
        logger.info("Fetching network details for place: \(place.name) (ID: \(place.placeId))")
        
        // Check if we have cached details for this place
        if let cachedDetails = cache.retrievePlaceDetails(forPlaceId: place.placeId) {
            logger.info("Using cached details for place ID: \(place.placeId)")
            
            // Cancel the loading indicator task if it hasn't shown yet
            loadingTask.cancel()
            isLoading = false
            
            // Update UI with cached data
            self.photos = cachedDetails.photos
            self.reviews = cachedDetails.reviews
            return
        }
        
        // No cache hit, need to fetch from network
        logger.info("Fetching details from network for place ID: \(place.placeId)")
        
        // Only cancel previous requests if the place ID has changed
        if currentPlaceId != place.placeId {
            service.cancelPlaceDetailsRequests()
        }
        
        service.fetchPlaceDetails(placeId: place.placeId) { [weak self] result in
            // Ensure UI updates happen on the main thread
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Cancel the loading indicator task if it hasn't shown yet
                loadingTask.cancel()
                self.isLoading = false
                
                switch result {
                case .success(let details):
                    self.logger.info("Successfully fetched details for place ID: \(place.placeId)")
                    self.photos = details.photos
                    self.reviews = details.reviews
                case .failure(let networkError):
                    self.error = networkError
                    
                    // Handle specific error types
                    if case .noResults = networkError {
                        // Provide haptic feedback for no results
                        let feedbackGenerator = UINotificationFeedbackGenerator()
                        feedbackGenerator.prepare()
                        feedbackGenerator.notificationOccurred(.warning)
                    }
                    
                    // Only show error alert if it's not a cancelled request
                    self.showError = networkError.shouldShowAlert
                    self.logger.error("Error fetching place details: \(networkError.localizedDescription)")
                }
            }
        }
    }
    
    func toggleFavorite() {
        // Only proceed if we're properly initialized
        guard isInitialized else {
            logger.error("❌ ERROR: Cannot toggle favorite - PlaceDetailViewModel not properly initialized")
            return
        }
        
        guard let placeId = currentPlaceId else {
            logger.error("❌ ERROR: Cannot toggle favorite - no current placeId")
            return
        }
        
        // Toggle the favorite status directly in the MapViewModel
        if isFavorite {
            mapViewModel.removeFavorite(placeId: placeId)
        } else {
            // We need the place object to add it as a favorite
            if let place = mapViewModel.places.first(where: { $0.placeId == placeId }) {
                mapViewModel.addFavorite(place)
            }
        }
        
        // Notify UI of change
        objectWillChange.send()
        
        logger.info("Favorite status updated to: \(!self.isFavorite)")
    }
    
    func ratePlace(rating: Int) {
        // Only proceed if we're properly initialized
        guard isInitialized else {
            logger.error("❌ ERROR: Cannot rate place - PlaceDetailViewModel not properly initialized")
            return
        }
        
        guard let placeId = currentPlaceId else {
            logger.error("❌ ERROR: Cannot rate place - no current placeId")
            return
        }
        
        logger.info("📝 INFO: Rating place with ID: \(placeId) with rating: \(rating)")
        
        // Update rating directly in the MapViewModel
        mapViewModel.ratePlace(placeId: placeId, rating: rating)
        
        // Notify UI of change
        objectWillChange.send()
        
        logger.info("📝 INFO: Rating updated to: \(rating)")
    }
    
    func retryFetchDetails(for place: Place) {
        fetchDetails(for: place)
    }
    
    // Method to call when the view disappears
    func onViewDisappear() {
        // Don't cancel requests when the view disappears
        // This allows the requests to complete even if the view is dismissed
        // The data will be available if the view is shown again
    }
    
    // Cancel all pending requests when the view model is deallocated
    deinit {
        // Only cancel place details requests, not all requests
        service.cancelPlaceDetailsRequests()
    }
    
    // Method to update the MapViewModel after initialization
    func updateMapViewModel(_ newMapViewModel: MapViewModel) {
        // This method allows us to update the MapViewModel reference after initialization
        // This is needed because we can't access the @EnvironmentObject in the initializer
        if self.mapViewModel !== newMapViewModel {
            // Only update if the reference is different
            self.mapViewModel = newMapViewModel
            self.isInitialized = true
            logger.info("MapViewModel updated in PlaceDetailViewModel, isInitialized set to true")
        }
    }
}
