//
//  PlaceSheetViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import Combine
import os.log

@MainActor
class PlaceSheetViewModel: ObservableObject {
    // Published properties for UI state
    @Published var isLoadingDetails = false
    @Published var isLoadingPhotos = false
    @Published var detailsError: String?
    @Published var photosError: String?
    
    // Place data
    @Published var place: Place
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceSheetViewModel")
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(place: Place) {
        self.place = place
        logger.notice("PlaceSheetViewModel initialized for place ID: \(place.id)")
    }
    
    // MARK: - Public Methods
    
    /// Fetch additional data for the place
    func fetchPlaceData() {
        logger.notice("Fetching additional data for place ID: \(self.place.id)")
        
        // Fetch details and photos concurrently
        fetchPlaceDetails()
        fetchPlacePhotos()
    }
    
    // MARK: - Private Methods
    
    /// Fetch place details from the API
    private func fetchPlaceDetails() {
        isLoadingDetails = true
        detailsError = nil
        
        guard let url = createURL(endpoint: "api/places/details", id: place.id) else {
            detailsError = "Invalid URL for details request"
            isLoadingDetails = false
            return
        }
        
        logger.notice("Fetching place details from: \(url.absoluteString)")
        
        URLSession.shared.dataTaskPublisher(for: url)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logger.error("Response is not an HTTP response")
                    throw URLError(.badServerResponse)
                }
                
                self.logger.notice("Received details response with status code: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.logger.error("Server returned error status code: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
                
                // Log the raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    self.logger.notice("Raw details response: \(jsonString.prefix(200))...")
                }
                
                return data
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoadingDetails = false
                    
                    if case .failure(let error) = completion {
                        self.detailsError = "Failed to load details: \(error.localizedDescription)"
                        self.logger.error("Error fetching place details: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] data in
                    guard let self = self else { return }
                    
                    // For now, just log the response
                    if let jsonString = String(data: data, encoding: .utf8) {
                        self.logger.notice("Details response: \(jsonString)")
                    } else {
                        self.logger.error("Could not convert details response to string")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Fetch place photos from the API
    private func fetchPlacePhotos() {
        isLoadingPhotos = true
        photosError = nil
        
        guard let url = createURL(endpoint: "api/places/photos", id: place.id) else {
            photosError = "Invalid URL for photos request"
            isLoadingPhotos = false
            return
        }
        
        logger.notice("Fetching place photos from: \(url.absoluteString)")
        
        URLSession.shared.dataTaskPublisher(for: url)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.logger.error("Response is not an HTTP response")
                    throw URLError(.badServerResponse)
                }
                
                self.logger.notice("Received photos response with status code: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.logger.error("Server returned error status code: \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
                
                // Log the raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    self.logger.notice("Raw photos response: \(jsonString.prefix(200))...")
                }
                
                return data
            }
            .decode(type: PhotosResponse.self, decoder: JSONDecoder())
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoadingPhotos = false
                    
                    if case .failure(let error) = completion {
                        self.photosError = "Failed to load photos: \(error.localizedDescription)"
                        self.logger.error("Error fetching place photos: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    
                    // Log the response
                    self.logger.notice("Received \(response.count) photos for place ID: \(self.place.id)")
                    
                    // Update the place model with the photos
                    self.place.photos = response.data
                    
                    // Log the first few photo URLs
                    if !response.data.isEmpty {
                        let sampleUrls = response.data.prefix(2).joined(separator: ", ")
                        self.logger.notice("Sample photo URLs: \(sampleUrls)")
                    } else {
                        self.logger.notice("No photos received for place ID: \(self.place.id)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Helper method to create URLs for API requests
    private func createURL(endpoint: String, id: String) -> URL? {
        var urlComponents = URLComponents(url: Configuration.backendURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = [URLQueryItem(name: "id", value: id)]
        
        guard let url = urlComponents?.url else {
            logger.error("Failed to create URL for endpoint: \(endpoint)")
            return nil
        }
        
        return url
    }
} 
