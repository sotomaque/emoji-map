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
import Clerk

@MainActor
class HomeViewModel: ObservableObject {
    // Published properties for UI state
    @Published var places: [Place] = []
    @Published var filteredPlaces: [Place] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterSheetPresented = false
    @Published var isSettingsSheetPresented = false
    @Published var selectedPlace: Place?
    @Published var isPlaceDetailSheetPresented = false
    
    // User data
    @Published var currentUser: User?
    @Published var isLoadingUser = false
    
    // Category selection state
    @Published var selectedCategoryKeys: Set<Int> = []
    @Published var isAllCategoriesMode: Bool = true
    @Published var showFavoritesOnly: Bool = false
    
    // Map state
    @Published var visibleRegion: MKCoordinateRegion?
    private var lastFetchedRegion: MKCoordinateRegion?
    private var regionChangeDebounceTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    
    // Location manager
    let locationManager = LocationManager()
    
    // Services
    let placesService: PlacesServiceProtocol
    let userPreferences: UserPreferences
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "HomeViewModel")
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(placesService: PlacesServiceProtocol, userPreferences: UserPreferences) {
        self.placesService = placesService
        self.userPreferences = userPreferences
        logger.notice("HomeViewModel initialized")
        
        setupLocationManager()
        
        // Fetch user data in the background
        Task {
            await fetchUserData()
        }
    }
    
    deinit {
        // Cancel any pending tasks
        regionChangeDebounceTask?.cancel()
        fetchTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Fetch user data from the API
    func fetchUserData() async {
        logger.notice("Checking for authenticated user")
        
        // Get Clerk instance
        let clerk = Clerk.shared
        
        // Make sure Clerk is fully loaded
        if !clerk.isLoaded {
            logger.notice("Clerk is not fully loaded yet. Skipping user data request.")
            return
        }
        
        // Check if user is authenticated
        if let clerkUser = clerk.user {
            logger.notice("User is authenticated with Clerk. User ID: \(clerkUser.id)")
            
            // Set loading state
            isLoadingUser = true
            
            do {
                // Get the network service from the service container
                let networkService = ServiceContainer.shared.networkService
                
                // Create query items with the user ID
                let queryItems = [URLQueryItem(name: "userId", value: clerkUser.id)]
                
                logger.notice("Making request to /api/user with userId: \(clerkUser.id)")
                
                // Make the request to the user endpoint with the user ID
                let userResponse: UserResponse = try await networkService.fetch(
                    endpoint: .user,
                    queryItems: queryItems,
                    authToken: nil
                )
                
                // Log the raw response structure
                logger.notice("User response received with user ID: \(userResponse.user.id)")
                
                // Convert the response to a User model
                let user = userResponse.toUser
                
                // Log the user data
                logger.notice("User data fetched successfully:")
                logger.notice("  ID: \(user.id)")
                logger.notice("  Email: \(user.email)")
                logger.notice("  Username: \(user.username ?? "N/A")")
                logger.notice("  Name: \(user.firstName ?? "") \(user.lastName ?? "")")
                
                if let createdAt = user.createdAt {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    logger.notice("  Created: \(formatter.string(from: createdAt))")
                }
                
                // Log favorites information
                logger.notice("  Favorites: \(user.favorites.count)")
                for (index, favorite) in user.favorites.enumerated() {
                    logger.notice("    Favorite \(index + 1): Place ID: \(favorite.placeId)")
                }
                
                // Store the user data
                currentUser = user
                
                // Save user ID and email to UserPreferences
                userPreferences.saveUserData(id: user.id, email: user.email)
                
                // Synchronize favorites with API data
                userPreferences.syncFavoritesWithAPI(apiFavorites: user.favorites)
                
                // Reset loading state
                isLoadingUser = false
            } catch {
                // Just log the error, don't show it to the user
                logger.error("Failed to fetch user data: \(error.localizedDescription)")
                
                // Reset loading state
                isLoadingUser = false
            }
        } else {
            // User is not authenticated, skip the request
            logger.notice("User is not authenticated with Clerk. Skipping user data request.")
            
            // Clear any existing user data
            currentUser = nil
        }
    }
    
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
                // Use the center of the current viewport instead of user location
                fetchNearbyPlaces(at: region.center)
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
    
    /// Toggle settings sheet
    func toggleSettingsSheet() {
        isSettingsSheetPresented.toggle()
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
    
    // MARK: - Category Selection Methods
    
    /// Toggle favorites filter
    func toggleFavoritesFilter() {
        showFavoritesOnly.toggle()
        logger.notice("Toggled favorites filter: \(self.showFavoritesOnly ? "ON" : "OFF")")
        
        if showFavoritesOnly {
            logger.notice("Showing only \(self.userPreferences.favoritePlaceIds.count) favorited places")
        }
        
        applyFilters()
    }
    
    /// Toggle all categories mode
    func toggleAllCategories() {
        isAllCategoriesMode.toggle()
        
        if isAllCategoriesMode {
            // Clear selected categories when "All" is selected
            selectedCategoryKeys.removeAll()
            logger.notice("All categories mode enabled, cleared selected categories")
        } else {
            logger.notice("All categories mode disabled")
        }
        
        logger.notice("Selected keys: \(self.selectedCategoryKeys)")
        applyFilters()
    }
    
    /// Toggle a specific category
    func toggleCategory(key: Int, emoji: String) {
        if selectedCategoryKeys.contains(key) {
            selectedCategoryKeys.remove(key)
            logger.notice("Deselected category with key: \(key) \(emoji)")
        } else {
            selectedCategoryKeys.insert(key)
            logger.notice("Selected category with key: \(key) \(emoji)")
        }
        
        // If no categories are selected, switch to "All" mode
        if selectedCategoryKeys.isEmpty {
            isAllCategoriesMode = true
            logger.notice("No categories selected, switched to All mode")
        } else {
            isAllCategoriesMode = false
            
            // Fetch places by categories when we have categories selected
            fetchPlacesByCategories()
        }
        
        logger.notice("Selected keys: \(self.selectedCategoryKeys)")
        applyFilters()
    }
    
    /// Apply filters to places based on selected categories
    private func applyFilters() {
        // Start with all places
        var filtered = places
        
        // Apply category filter if not in "All" mode
        if !isAllCategoriesMode && !selectedCategoryKeys.isEmpty {
            // Convert emoji to keys for filtering
            let emojiToKeyMap: [String: Int] = [
                "🍕": 1, "🍺": 2, "🍣": 3, "☕️": 4, "🍔": 5,
                "🌮": 6, "🍜": 7, "🥗": 8, "🍦": 9, "🍷": 10,
                "🍲": 11, "🥪": 12, "🍝": 13, "🥩": 14, "🍗": 15,
                "🍤": 16, "🍛": 17, "🥘": 18, "🍱": 19, "🥟": 20,
                "🧆": 21, "🥐": 22, "🍨": 23, "🍹": 24, "🍽️": 25
            ]
            
            filtered = filtered.filter { place in
                if let key = emojiToKeyMap[place.emoji] {
                    return selectedCategoryKeys.contains(key)
                }
                return false
            }
        }
        
        // Apply favorites filter
        if showFavoritesOnly {
            filtered = filtered.filter { place in
                return userPreferences.isFavorite(placeId: place.id)
            }
        }
        
        // Update filtered places
        filteredPlaces = filtered
        logger.notice("Applied filters: showing \(self.filteredPlaces.count) of \(self.places.count) places")
    }
    
    /// Fetch places by selected category keys
    private func fetchPlacesByCategories() {
        // Only proceed if we have categories selected
        guard !selectedCategoryKeys.isEmpty else {
            logger.notice("No categories selected, skipping category-specific fetch")
            return
        }
        
        // Cancel any existing fetch task
        fetchTask?.cancel()
        
        // Only proceed if we have a location
        guard let location = visibleRegion?.center ?? locationManager.lastLocation?.coordinate else {
            logger.error("Cannot fetch places by categories: No location available")
            return
        }
        
        logger.notice("Fetching places by categories: \(self.selectedCategoryKeys)")
        
        // Create a new fetch task
        fetchTask = Task {
            do {
                let fetchedPlaces = try await placesService.fetchPlacesByCategories(
                    location: location,
                    categoryKeys: Array(selectedCategoryKeys)
                )
                
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                // Merge new places with existing places
                mergePlaces(fetchedPlaces)
                logger.notice("Fetched \(fetchedPlaces.count) places by categories, total places now: \(self.places.count)")
                
                // Apply filters to update filtered places
                applyFilters()
            } catch {
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                errorMessage = "Failed to load places by categories: \(error.localizedDescription)"
                logger.error("Error fetching places by categories: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check if a place is favorited by the current user
    func isPlaceFavorited(placeId: String) -> Bool {
        guard let user = currentUser else {
            return false
        }
        
        return user.favorites.contains { $0.placeId == placeId }
    }
    
    /// Get the favorite object for a place if it exists
    func getFavorite(for placeId: String) -> Favorite? {
        guard let user = currentUser else {
            return nil
        }
        
        return user.favorites.first { $0.placeId == placeId }
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
    
    /// Fetch nearby places from the service using async/await
    private func fetchNearbyPlaces(at coordinate: CLLocationCoordinate2D, useCache: Bool = true) {
        // Cancel any existing fetch task
        fetchTask?.cancel()
        
        // Only show loading indicator if we have no places to display
        let shouldShowLoading = places.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        
        errorMessage = nil
        
        // Store the current region as the last fetched region
        lastFetchedRegion = visibleRegion
        
        logger.notice("Fetching nearby places at \(coordinate.latitude), \(coordinate.longitude)")
        
        // Create a new fetch task
        fetchTask = Task {
            do {
                let fetchedPlaces = try await placesService.fetchNearbyPlaces(
                    location: coordinate,
                    useCache: useCache
                )
                
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                // Merge new places with existing places instead of replacing
                mergePlaces(fetchedPlaces)
                logger.notice("Fetched \(fetchedPlaces.count) places, total places now: \(self.places.count)")
                
                // Apply filters to update filtered places
                applyFilters()
                
                // Hide loading indicator if it was showing
                if shouldShowLoading {
                    isLoading = false
                }
            } catch {
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                // Only hide loading if we were showing it
                if shouldShowLoading {
                    isLoading = false
                }
                
                errorMessage = "Failed to load places: \(error.localizedDescription)"
                logger.error("Error fetching places: \(error.localizedDescription)")
            }
        }
    }
    
    /// Fetch nearby places from the service using Combine (legacy method)
    private func fetchNearbyPlacesWithCombine(at coordinate: CLLocationCoordinate2D, useCache: Bool = true) {
        // Only show loading indicator if we have no places to display
        let shouldShowLoading = places.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        
        errorMessage = nil
        
        // Store the current region as the last fetched region
        lastFetchedRegion = visibleRegion
        
        logger.notice("Fetching nearby places at \(coordinate.latitude), \(coordinate.longitude)")
        
        placesService.fetchNearbyPlacesPublisher(location: coordinate, useCache: useCache)
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
                
                // Apply filters to update filtered places
                self.applyFilters()
                
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
        filteredPlaces.removeAll()
        logger.notice("Cleared all places")
    }
} 
