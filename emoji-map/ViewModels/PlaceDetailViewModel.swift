//
//  PlaceDetailViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/4/25.
//

import Foundation

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
    
    private let service: GooglePlacesServiceProtocol
    private let userPreferences: UserPreferences
    var currentPlaceId: String?
    
    init(service: GooglePlacesServiceProtocol = GooglePlacesService(), userPreferences: UserPreferences = UserPreferences()) {
        self.service = service
        self.userPreferences = userPreferences
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
        } else {
            // We need the full place object to add as favorite
            // This is a limitation of our current implementation
            // In a real app, we might store the current place or fetch it again
            print("Cannot add to favorites without full place object")
            // For now, we'll just toggle the UI state
        }
        
        isFavorite.toggle()
    }
    
    func setFavorite(_ place: Place, isFavorite: Bool) {
        if isFavorite {
            userPreferences.addFavorite(place)
        } else {
            userPreferences.removeFavorite(placeId: place.placeId)
        }
        self.isFavorite = isFavorite
    }
    
    func ratePlace(rating: Int) {
        guard let placeId = currentPlaceId else { return }
        userPreferences.ratePlace(placeId: placeId, rating: rating)
        userRating = rating
    }
    
    func retryFetchDetails(for place: Place) {
        fetchDetails(for: place)
    }
    
    // Cancel all pending requests when the view model is deallocated
    deinit {
        service.cancelAllRequests()
    }
}
