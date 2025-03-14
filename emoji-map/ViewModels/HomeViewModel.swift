//
//  HomeViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import CoreLocation
import MapKit
import Combine
import os.log

@MainActor
class HomeViewModel: ObservableObject {
    // Published properties for UI state
    @Published var places: [Place] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterSheetPresented = false
    @Published var selectedPlace: Place?
    @Published var isPlaceDetailSheetPresented = false
    
    // Map state
    @Published var visibleRegion: MKCoordinateRegion?
    private var lastFetchedRegion: MKCoordinateRegion?
    private var regionChangeDebounceTask: Task<Void, Never>?
    
    // Location manager
    let locationManager = LocationManager()
    
    // Services
    private let placesService: PlacesService
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "HomeViewModel")
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(placesService: PlacesService) {
        self.placesService = placesService
        logger.notice("HomeViewModel initialized")
        
        setupLocationManager()
    }
    
    deinit {
        // Cancel any pending region change tasks
        regionChangeDebounceTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Setup location manager and handle location updates
    func setupLocationManager() {
        locationManager.requestAuthorization()
        locationManager.onLocationUpdate = { [weak self] coordinate in
            guard let self = self else { return }
            
            // Only fetch on first location update
            if self.lastFetchedRegion == nil {
                self.fetchNearbyPlaces(at: coordinate)
            }
        }
    }
    
    /// Handle map region changes with debouncing
    func handleMapRegionChange(_ region: MKCoordinateRegion) {
        visibleRegion = region
        
        // Cancel any existing debounce task
        regionChangeDebounceTask?.cancel()
        
        // Create a new debounce task
        regionChangeDebounceTask = Task {
            // Wait for 1 second of inactivity before fetching
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Check if the task was cancelled
            if Task.isCancelled { return }
            
            // Check if we need to fetch new data based on region change
            if shouldFetchForRegion(region) {
                await MainActor.run {
                    // Use the center of the current viewport instead of user location
                    fetchNearbyPlaces(at: region.center)
                }
            }
        }
    }
    
    /// Refresh places based on current location
    /// - Parameter clearExisting: Whether to clear existing places before refreshing (default: false)
    func refreshPlaces(clearExisting: Bool = false) {
        // Clear existing places if requested
        if clearExisting {
            places.removeAll()
            logger.notice("Cleared existing places for full refresh")
        }
        
        if let region = visibleRegion {
            // Use the current viewport center if available
            fetchNearbyPlaces(at: region.center, useCache: false)
        } else if let location = locationManager.lastLocation?.coordinate {
            // Fall back to user location if no viewport is available
            fetchNearbyPlaces(at: location, useCache: false)
        } else {
            errorMessage = "Unable to determine your location"
            logger.error("Refresh failed: No location available")
        }
    }
    
    /// Toggle filter sheet
    func toggleFilterSheet() {
        isFilterSheetPresented.toggle()
    }
    
    /// Select a place and show its detail sheet
    func selectPlace(_ place: Place) {
        selectedPlace = place
        isPlaceDetailSheetPresented = true
        logger.notice("Selected place: \(place.id)")
    }
    
    /// Dismiss the place detail sheet
    func dismissPlaceDetail() {
        selectedPlace = nil
        isPlaceDetailSheetPresented = false
    }
    
    // MARK: - Private Methods
    
    /// Determine if we should fetch new data based on region change
    private func shouldFetchForRegion(_ region: MKCoordinateRegion) -> Bool {
        guard let lastRegion = lastFetchedRegion else {
            // If we haven't fetched yet, we should fetch
            return true
        }
        
        // Calculate how much the region has changed
        let centerDelta = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            .distance(from: CLLocation(latitude: lastRegion.center.latitude, longitude: lastRegion.center.longitude))
        
        // Calculate the average span of the current region in meters
        let currentSpanMeters = (region.span.latitudeDelta * 111000 + region.span.longitudeDelta * 111000) / 2
        
        // If the center has moved more than 25% of the visible region, fetch new data
        let significantMove = centerDelta > (currentSpanMeters * 0.25)
        
        // If the zoom level has changed significantly (more than 50% difference), fetch new data
        let lastSpanMeters = (lastRegion.span.latitudeDelta * 111000 + lastRegion.span.longitudeDelta * 111000) / 2
        let zoomRatio = currentSpanMeters / lastSpanMeters
        let significantZoom = zoomRatio < 0.5 || zoomRatio > 2.0
        
        return significantMove || significantZoom
    }
    
    /// Fetch nearby places from the service
    private func fetchNearbyPlaces(at coordinate: CLLocationCoordinate2D, useCache: Bool = true) {
        // Only show loading indicator if we have no places to display
        let shouldShowLoading = places.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        
        errorMessage = nil
        
        // Store the current region as the last fetched region
        lastFetchedRegion = visibleRegion
        
        logger.notice("Fetching nearby places at \(coordinate.latitude), \(coordinate.longitude)")
        
        placesService.fetchNearbyPlaces(location: coordinate, useCache: useCache)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                // Only hide loading if we were showing it
                if shouldShowLoading {
                    self.isLoading = false
                }
                
                if case .failure(let error) = completion {
                    self.errorMessage = "Failed to load places: \(error.localizedDescription)"
                    self.logger.error("Error fetching places: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] fetchedPlaces in
                guard let self = self else { return }
                
                // Merge new places with existing places instead of replacing
                self.mergePlaces(fetchedPlaces)
                self.logger.notice("Fetched \(fetchedPlaces.count) places, total places now: \(self.places.count)")
                
                // Hide loading indicator if it was showing
                if shouldShowLoading {
                    self.isLoading = false
                }
            })
            .store(in: &cancellables)
    }
    
    /// Merge new places with existing places, avoiding duplicates
    private func mergePlaces(_ newPlaces: [Place]) {
        // Create a dictionary of existing places by ID for efficient lookup
        let existingPlacesById = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        
        // Count before adding
        let countBefore = places.count
        
        // Add only places that don't already exist
        for place in newPlaces {
            if existingPlacesById[place.id] == nil {
                places.append(place)
            }
        }
        
        // Log how many new places were added
        let addedCount = places.count - countBefore
        if addedCount > 0 {
            logger.notice("Added \(addedCount) new unique places, total now: \(self.places.count)")
        } else {
            logger.notice("No new unique places to add, total remains: \(self.places.count)")
        }
    }
    
    /// Clear all places (useful for reset functionality if needed)
    func clearPlaces() {
        places.removeAll()
        logger.notice("Cleared all places")
    }
} 
