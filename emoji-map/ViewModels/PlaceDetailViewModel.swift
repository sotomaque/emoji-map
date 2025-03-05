//
//  PlaceDetailViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/4/25.
//

import Foundation


class PlaceDetailViewModel: ObservableObject {
    @Published var photos: [String] = []
    @Published var reviews: [(String, String, Int)] = []
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showError = false
    
    private let service: GooglePlacesServiceProtocol = GooglePlacesService()
    
    func fetchDetails(for placeId: String) {
        isLoading = true
        error = nil
        showError = false
        
        service.fetchPlaceDetails(placeId: placeId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let details):
                    self.photos = details.photos
                    self.reviews = details.reviews
                case .failure(let networkError):
                    self.error = networkError
                    self.showError = true
                    print("Error fetching place details: \(networkError.localizedDescription)")
                }
            }
        }
    }
    
    func retryFetchDetails(for placeId: String) {
        fetchDetails(for: placeId)
    }
}
