//
//  PlaceDetailViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/4/25.
//

import Foundation
import UIKit

// Thread-safe actor for managing shared state
@MainActor
class PlaceDetailViewModel: ObservableObject {
    @Published var photos: [String] = []
    @Published var reviews: [(String, String, Int)] = []
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showError = false
    @Published var isFavorite = false
    @Published var userRating: Int = 0
    
    // Computed property to convert tuple reviews to Review objects
    var reviewObjects: [Review] {
        return reviews.map { Review(authorName: $0.0, text: $0.1, rating: $0.2) }
    }
    
    private let userPreferences: UserPreferences
    var currentPlaceId: String?
    
    // Make service a private variable instead of a constant so we can update it
    private var service: GooglePlacesServiceProtocol
    
    init(service: GooglePlacesServiceProtocol? = nil, userPreferences: UserPreferences? = nil) {
        // Use the provided service or get the shared instance
        self.service = service ?? ServiceContainer.shared.googlePlacesService
        // Use the provided userPreferences or get the shared instance
        self.userPreferences = userPreferences ?? ServiceContainer.shared.userPreferences
    }
    
    // Method to update the service after initialization - no longer needed but kept for compatibility
    func updateService(_ newService: GooglePlacesServiceProtocol) {
        // Cancel any pending requests on the old service
        self.service.cancelAllRequests()
        // Update to the new service
        self.service = newService
    }
    
    func fetchDetails(for place: Place) {
        isLoading = true
        error = nil
        showError = false
        currentPlaceId = place.placeId
        
        // Check if place is a favorite
        isFavorite = userPreferences.isFavorite(placeId: place.placeId)
        
        // Get user rating if available
        userRating = userPreferences.getRating(for: place.placeId) ?? 0
        
        // Cancel any previous requests before starting a new one
        service.cancelPlaceDetailsRequests()
        
        service.fetchPlaceDetails(placeId: place.placeId) { [weak self] result in
            // Ensure UI updates happen on the main thread
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let details):
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
                    print("Error fetching place details: \(networkError.localizedDescription)")
                }
            }
        }
    }
    
    func toggleFavorite() {
        guard let placeId = currentPlaceId else { return }
        
        if isFavorite {
            userPreferences.removeFavorite(placeId: placeId)
            isFavorite = false
        } else {
            // We can't add to favorites without the full place object
            // This method should not be called directly - use setFavorite instead
            print("Warning: Cannot add to favorites without full place object. Use setFavorite instead.")
            // Don't change the isFavorite state since we couldn't actually add it
        }
        
        // Notify UI of change
        objectWillChange.send()
    }
    
    func setFavorite(_ place: Place, isFavorite: Bool) {
        print("PlaceDetailViewModel.setFavorite called for \(place.name), setting to \(isFavorite)")
        
        if isFavorite {
            userPreferences.addFavorite(place)
        } else {
            userPreferences.removeFavorite(placeId: place.placeId)
        }
        
        // Update the local state
        self.isFavorite = isFavorite
        
        // Debug: Print favorites after change
        print("After setting favorite in PlaceDetailViewModel:")
        userPreferences.printFavorites()
        
        // Notify UI of change
        objectWillChange.send()
    }
    
    func ratePlace(rating: Int) {
        guard let placeId = currentPlaceId else { return }
        userPreferences.ratePlace(placeId: placeId, rating: rating)
        userRating = rating
        
        // Notify UI of change
        objectWillChange.send()
    }
    
    func retryFetchDetails(for place: Place) {
        fetchDetails(for: place)
    }
    
    // Cancel all pending requests when the view model is deallocated
    deinit {
        service.cancelAllRequests()
    }
}
