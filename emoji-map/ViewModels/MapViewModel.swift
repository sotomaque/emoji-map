//
//  MapViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit
import CoreLocation
import os.log
import Combine

// Thread-safe actor for managing shared state
@MainActor
class MapViewModel: ObservableObject {
    // Add a logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "MapViewModel")
    
    // Use the emojis from CategoryMappings
    var categoryEmojis: [String] {
        return CategoryMappings.allEmojis
    }
    
    // New property to map emoji to category key
    private var categoryKeys: [String: Int] {
        return CategoryMappings.emojiToKey
    }
    
    @Published var selectedCategories: Set<String> = []
    @Published var isAllCategoriesMode: Bool = true // New state to track if "All" is active
    @Published var region: MKCoordinateRegion
    @Published var places: [Place] = []
    @Published var selectedPlace: Place?
    @Published private(set) var lastQueriedCenter: CoordinateWrapper
    @Published var isLoading: Bool = false
    @Published var error: NetworkError?
    @Published var showError: Bool = false
    @Published var showConfigWarning: Bool = false
    @Published var configWarningMessage: String = ""
    @Published var showFavoritesOnly: Bool = false
    @Published var notificationMessage: String = ""
    @Published var showNotification: Bool = false
    @Published var showSearchHereButton: Bool = false // New property to show the "Search Here" button
    
    // Location permission properties
    @Published var showLocationPermissionView: Bool = false
    
    // Callback for region changes
    var onRegionDidChange: ((MKCoordinateRegion) -> Void)?
    
    // Filter properties
    @Published var selectedPriceLevels: Set<Int> = [
        1,
        2,
        3,
        4
    ] // 1-4 representing $ to $$$$
    @Published var showOpenNowOnly: Bool = false
    @Published var minimumRating: Int = 0 // 0-5 stars, 0 means no filter
    @Published var useLocalRatings: Bool = false // Whether to use local ratings instead of Google ratings
    @Published var showFilters: Bool = false // Controls filter sheet visibility
    
    // Add this property near the top of the class with other @Published properties
    @Published var newPlacesLoaded = false
    // Track existing place IDs to determine which places are truly new
    private var existingPlaceIds = Set<String>()
    
    private let backendService: BackendService
    private let userPreferences: UserPreferences
    private var shouldCenterOnLocation = true
    
    // Add a cancellable for the notification subscription
    private var updateSubscription: AnyCancellable?
    
    // Make locationManager accessible to other views
    let locationManager: LocationManager
    
    // Add a reference to the cache
    private let cache = NetworkCache.shared
    
    // Public getter for userPreferences
    var preferences: UserPreferences {
        return userPreferences
    }
    
    // Computed property to check if all categories are selected
    var areAllCategoriesSelected: Bool {
        selectedCategories.count == categoryEmojis.count && categoryEmojis
            .allSatisfy { selectedCategories.contains($0) }
    }
    
    var activeFilterCount: Int {
        var count = 0
        
        // Count price level filters
        if selectedPriceLevels.count < 4 {
            count += 1
        }
        
        // Count open now filter
        if showOpenNowOnly {
            count += 1
        }
        
        // Count minimum rating filter
        if minimumRating > 0 {
            count += 1
        }
        
        return count
    }
    
    var isLocationAvailable: Bool {
        locationManager.location != nil
    }
    
    var isLocationPermissionDenied: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }
    
    var filteredPlaces: [Place] {
        // Start with all places
        var filtered = places
        
        // Get a direct reference to UserPreferences to ensure we have the latest data
        let userPrefs = ServiceContainer.shared.userPreferences
        
        // Log the initial state
        let initialCount = filtered.count
        
        // Filter by favorites if enabled
        if showFavoritesOnly {
            filtered = filtered.filter { place in
                userPrefs.isFavorite(placeId: place.placeId)
            }
            logger.debug("FILTER: Favorites filter applied - \(initialCount) → \(filtered.count) places")
        }
        
        // Filter by categories
        if !selectedCategories.isEmpty && !isAllCategoriesMode {
            let beforeCategoryFilter = filtered.count
            filtered = filtered.filter { place in
                // If the category is empty, include it in all categories
                if place.category.isEmpty {
                    logger.debug("Including place with empty category: \(place.name)")
                    return true
                }
                
                // Check if the category matches any of the selected categories
                let matches = selectedCategories.contains(place.category)
                
                // If it doesn't match directly, check if it's a partial match
                // This helps with cases where the backend might return a more specific category
                // than what we have in our selected categories
                if !matches {
                    // Check if any selected category is a substring of the place's category
                    // or if the place's category is a substring of any selected category
                    let partialMatches = selectedCategories.contains { selectedCategory in
                        place.category.contains(selectedCategory) || selectedCategory.contains(place.category)
                    }
                    
                    if partialMatches {
                        logger.debug("Including place \(place.name) with partial category match: '\(place.category)'")
                        return true
                    }
                    
                    logger.debug("Filtering out place \(place.name) with category '\(place.category)' - not in selected categories")
                }
                
                return matches
            }
            logger.debug("FILTER: Category filter applied - \(beforeCategoryFilter) → \(filtered.count) places")
        }
        
        // Filter by price level
        if selectedPriceLevels.count < 4 { // If not all price levels are selected
            let beforePriceFilter = filtered.count
            filtered = filtered.filter { place in
                if let priceLevel = place.priceLevel {
                    return selectedPriceLevels.contains(priceLevel)
                }
                return true // Include places with no price level information
            }
            logger.debug("FILTER: Price level filter applied - \(beforePriceFilter) → \(filtered.count) places")
        }
        
        // Filter by open now status
        if showOpenNowOnly {
            let beforeOpenFilter = filtered.count
            filtered = filtered.filter { place in
                place.openNow == true
            }
            logger.debug("FILTER: Open now filter applied - \(beforeOpenFilter) → \(filtered.count) places")
        }
        
        // Filter by minimum rating
        if minimumRating > 0 {
            let beforeRatingFilter = filtered.count
            if useLocalRatings {
                // Use local user ratings
                filtered = filtered.filter { place in
                    if let rating = userPrefs.getRating(for: place.placeId) {
                        return rating >= minimumRating
                    }
                    return false // Exclude places with no local rating if minimum rating is set
                }
            } else {
                // Use Google ratings
                filtered = filtered.filter { place in
                    if let rating = place.rating {
                        return rating >= Double(minimumRating)
                    }
                    return false // Exclude places with no rating if minimum rating is set
                }
            }
            logger.debug("FILTER: Rating filter applied - \(beforeRatingFilter) → \(filtered.count) places")
        }
        
        // Log the final result
        logger.debug("FILTER: Final filtered places: \(initialCount) → \(filtered.count)")
        
        return filtered
    }
    
    // Debounce mechanism for fetch requests
    private var fetchDebounceTask: Task<Void, Never>?
    private var lastFetchTime: Date = Date.distantPast
    private var isFetchingPlaces: Bool = false
    private let fetchDebounceInterval: TimeInterval = 0.5 // 0.5 second debounce for more responsive updates
    
    // Add a property for region change debounce
    private var regionChangeDebounceTask: Task<Void, Never>?
    private let regionChangeDebounceInterval: TimeInterval = 0.5 // 0.5 second debounce for region changes
    
    // Enhanced caching system
    private var allCategoriesCache: [Place] = []
    private var lastCachedCenter: CoordinateWrapper?
    // Add a viewport-based cache dictionary to store places by region
    private var viewportCache: [String: [Place]] = [:]
    
    // Debug logging for cache operations
    private func logCacheStatus(operation: String, details: String = "") {
        let cacheSize = allCategoriesCache.count
        let viewportCacheCount = viewportCache.count
        let viewportCacheTotalPlaces = viewportCache.values.map { $0.count }.reduce(0, +)
        
        logger.notice("CACHE [\(operation)] - All categories cache: \(cacheSize) places, Viewport caches: \(viewportCacheCount) regions with \(viewportCacheTotalPlaces) total places \(details)")
    }
    
    // Generate a cache key for a specific viewport
    private func viewportCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Round coordinates to reduce cache fragmentation (within ~100m)
        let roundedLat = round(coordinate.latitude * 100) / 100
        let roundedLng = round(coordinate.longitude * 100) / 100
        return "viewport_\(roundedLat)_\(roundedLng)"
    }
    
    init(
        backendService: BackendService? = nil,
        userPreferences: UserPreferences? = nil
    ) {
        // Use the provided service or get the shared instance from ServiceContainer
        self.backendService = backendService ?? ServiceContainer.shared.backendService
        // Use the provided userPreferences or get the shared instance from ServiceContainer
        self.userPreferences = userPreferences ?? ServiceContainer.shared.userPreferences
        self.locationManager = LocationManager()
        
        // Set default coordinate (San Francisco)
        let defaultCoordinate = CLLocationCoordinate2D(
            latitude: 37.7749,
            longitude: -122.4194
        )
        self.region = MKCoordinateRegion(
            center: defaultCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self.lastQueriedCenter = CoordinateWrapper(defaultCoordinate)
        
        // Initialize selectedCategories with all category IDs
        self.selectedCategories = Set(categoryEmojis)
        
        // Initialize isAllCategoriesMode to true since we're starting with all categories selected
        self.isAllCategoriesMode = true
        
        // Explicitly request location authorization if not determined
        if locationManager.authorizationStatus == .notDetermined {
            print("Requesting location authorization during initialization")
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Setup location updates
        setupLocationUpdates()
        
        // Subscribe to update notifications
        setupNotificationSubscription()
        
        // Debug: Print current favorites on initialization
        print("MapViewModel initialized")
        userPreferences?.printFavorites()
    }
    
    
    private func setupLocationUpdates() {
        // Listen for authorization status changes
        locationManager.onAuthorizationStatusChange = { [weak self] status in
            guard let self = self else { return }
            
            print("Authorization status changed to: \(status)")
            
            // Show location permission view if access is denied or restricted
            if status == .denied || status == .restricted {
                self.showLocationPermissionView = true
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                // If authorization was just granted, start updating location
                print("Location authorization granted, starting updates")
                self.locationManager.startUpdatingLocation()
                self.showLocationPermissionView = false
            } else {
                self.showLocationPermissionView = false
            }
        }
        
        // Track if we've already processed a location update
        var initialLocationProcessed = false
        
        // Ensure location updates are handled on the main actor
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            
            print("Received location update: \(location.coordinate)")
            
            // Only process the first location update to prevent multiple fetches
            if !initialLocationProcessed && self.shouldCenterOnLocation {
                initialLocationProcessed = true
                print("Processing initial location update")
                
                // Since we're using @MainActor, this will be dispatched to the main thread
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.updateRegion(to: location.coordinate)
                    self.lastQueriedCenter = CoordinateWrapper(location.coordinate)
                    try await self.fetchAndUpdatePlaces()
                    self.shouldCenterOnLocation = false
                }
            }
        }
        
        // Check initial authorization status
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            print("Location access denied or restricted")
            showLocationPermissionView = true
        } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            print("Location access already authorized")
            // If we already have a location, use it
            if let initialLocation = locationManager.location {
                print("Using existing location: \(initialLocation.coordinate)")
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.updateRegion(to: initialLocation.coordinate)
                    self.lastQueriedCenter = CoordinateWrapper(initialLocation.coordinate)
                    try await self.fetchAndUpdatePlaces()
                    self.shouldCenterOnLocation = false
                }
            } else {
                print("No location available yet, waiting for updates")
                // Start location updates to get the current location
                locationManager.startUpdatingLocation()
            }
        } else {
            print("Location authorization not determined yet")
            // Request authorization if not determined
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func setupNotificationSubscription() {
        // Subscribe to the update notification
        updateSubscription = NotificationCenter.default.publisher(for: Notification.Name("ServiceContainer.updateAllViewModels"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Force UI refresh
                self?.objectWillChange.send()
            }
    }
    
    func toggleCategory(_ category: String) {
        // Provide haptic feedback
        HapticsManager.shared.prepareGenerators()
        
        // Log the current state before toggling
        logger.notice("Toggling category: \(category)")
        logger.notice("Current state - isAllCategoriesMode: \(self.isAllCategoriesMode), selectedCategories: \(self.selectedCategories.joined(separator: ", "))")
        
        // Store whether we're adding or removing a category
        let isAddingCategory: Bool
        
        // If "All" is currently selected and we're selecting a specific category
        if isAllCategoriesMode {
            // Turn off "All" mode
            isAllCategoriesMode = false
            // Clear all categories
            selectedCategories.removeAll()
            // Add only the selected category
            selectedCategories.insert(category)
            // Stronger feedback for selection
            HapticsManager.shared.mediumImpact(intensity: 0.8)
            
            logger.notice("Switched from All mode to single category: \(category)")
            
            // Store the current places as the "all categories" cache if it's not already set
            if allCategoriesCache.isEmpty {
                allCategoriesCache = places
                lastCachedCenter = lastQueriedCenter
                logCacheStatus(operation: "STORE", details: "Stored all categories from current places")
            }
            
            isAddingCategory = true // We're narrowing the filter, but we want to fetch new data
        } else {
            // Normal toggle behavior when "All" is not selected
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
                // Lighter feedback for deselection
                HapticsManager.shared.lightImpact(intensity: 0.6)
                
                logger.notice("Removed category: \(category)")
                isAddingCategory = false // We're removing a filter
                
                // If we removed a category and now no categories are selected, set isAllCategoriesMode to true
                // This ensures we always have at least one category selected
                if selectedCategories.isEmpty {
                    isAllCategoriesMode = true
                    selectedCategories = Set(categoryEmojis)
                    logger.notice("No categories selected, switching back to All mode")
                }
            } else {
                selectedCategories.insert(category)
                // Stronger feedback for selection
                HapticsManager.shared.mediumImpact(intensity: 0.8)
                
                logger.notice("Added category: \(category)")
                isAddingCategory = true // We're adding a filter
                
                // If we added a category and now all categories are selected, set isAllCategoriesMode to true
                if areAllCategoriesSelected {
                    isAllCategoriesMode = true
                    logger.notice("All categories selected, switching to All mode")
                }
            }
        }
        
        // Log the new state after toggling
        logger.notice("New state - isAllCategoriesMode: \(self.isAllCategoriesMode), selectedCategories: \(self.selectedCategories.joined(separator: ", "))")
        
        // Update notification if favorites filter is active
        if showFavoritesOnly {
            if isAllCategoriesMode {
                showNotificationMessage("Showing all favorites")
            } else {
                let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(
                    separator: ", "
                )
                showNotificationMessage(
                    "Showing favorites in: \(categoryNames)"
                )
            }
        }
        
        // Check if we can use the cached data
        let viewportKey = viewportCacheKey(for: lastQueriedCenter.coordinate)
        let hasViewportCache = viewportCache[viewportKey] != nil && !viewportCache[viewportKey]!.isEmpty
        
        let canUseCache = (!allCategoriesCache.isEmpty && 
                         lastCachedCenter != nil && 
                         lastCachedCenter?.coordinate.latitude == lastQueriedCenter.coordinate.latitude &&
                         lastCachedCenter?.coordinate.longitude == lastQueriedCenter.coordinate.longitude) || hasViewportCache
        
        // ALWAYS use the cache for immediate UI update, regardless of adding or removing
        if canUseCache {
            logCacheStatus(operation: "USE", details: "Using cache for immediate filtering - \(isAddingCategory ? "adding" : "removing") category")
            
            // Get the source data for filtering
            var sourcePlaces: [Place] = []
            
            if hasViewportCache {
                sourcePlaces = viewportCache[viewportKey]!
                logger.notice("Using viewport cache with \(sourcePlaces.count) places for immediate filtering")
            } else if !allCategoriesCache.isEmpty {
                sourcePlaces = allCategoriesCache
                logger.notice("Using all categories cache with \(sourcePlaces.count) places for immediate filtering")
            } else {
                // This should not happen, but just in case
                sourcePlaces = places
                logger.notice("Using current places (\(sourcePlaces.count)) for immediate filtering - no cache available")
            }
            
            // Filter the cached data based on selected categories
            if isAllCategoriesMode {
                // If "All" mode is selected, use all cached places
                places = sourcePlaces
                logger.notice("Using all \(self.places.count) places from cache")
            } else {
                // Otherwise, filter the cached places by the selected categories
                places = sourcePlaces.filter { place in
                    // If the category is empty, include it in all categories
                    if place.category.isEmpty {
                        return true
                    }
                    
                    // Check if the category matches any of the selected categories
                    let matches = selectedCategories.contains(place.category)
                    
                    // If it doesn't match directly, check if it's a partial match
                    if !matches {
                        // Check if any selected category is a substring of the place's category
                        // or if the place's category is a substring of any selected category
                        let partialMatches = selectedCategories.contains { selectedCategory in
                            place.category.contains(selectedCategory) || selectedCategory.contains(place.category)
                        }
                        
                        if partialMatches {
                            return true
                        }
                    }
                    
                    return matches
                }
                
                logger.notice("Filtered to \(self.places.count) places from cache based on selected categories")
            }
            
            // Trigger UI update
            objectWillChange.send()
            
            // Show notification about the filter
            if !isAllCategoriesMode {
                let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(separator: ", ")
                showNotificationMessage("Showing \(categoryNames)")
            } else {
                showNotificationMessage("Showing all categories")
            }
        } else {
            // If we don't have a cache, show a loading state
            logger.notice("No cache available, showing loading state")
            showNotificationMessage("Loading places...")
        }
        
        // If we're adding a specific category (not "All"), make a background request for that category
        if isAddingCategory && !isAllCategoriesMode {
            // Make a background request for the specific category to grow our cache
            Task { [weak self] in
                guard let self = self else { return }
                
                logger.notice("Making background request for category: \(category)")
                
                do {
                    // Only fetch the specific category we just added
                    let specificCategoryPlaces = try await fetchPlaces(
                        center: region.center,
                        region: self.region,
                        categories: [category]
                    )
                    
                    await MainActor.run {
                        logger.notice("Received \(specificCategoryPlaces.count) places for category \(category)")
                        
                        // If we have an all categories cache, merge the new places into it
                        if !allCategoriesCache.isEmpty {
                            // Create a set of existing place IDs for fast lookup
                            let existingPlaceIds = Set(allCategoriesCache.map { $0.placeId })
                            
                            // Add only new places to the cache
                            let newPlaces = specificCategoryPlaces.filter { !existingPlaceIds.contains($0.placeId) }
                            
                            if !newPlaces.isEmpty {
                                allCategoriesCache.append(contentsOf: newPlaces)
                                logCacheStatus(operation: "GROW", details: "Added \(newPlaces.count) new places to all categories cache")
                                
                                // Update the viewport cache as well
                                let viewportKey = viewportCacheKey(for: region.center)
                                if viewportCache[viewportKey] != nil {
                                    viewportCache[viewportKey]!.append(contentsOf: newPlaces)
                                    logCacheStatus(operation: "GROW", details: "Added \(newPlaces.count) new places to viewport cache")
                                } else {
                                    viewportCache[viewportKey] = specificCategoryPlaces
                                    logCacheStatus(operation: "CREATE", details: "Created new viewport cache with \(specificCategoryPlaces.count) places")
                                }
                                
                                // If we're still showing the same category, update the displayed places
                                if selectedCategories.contains(category) && !isAllCategoriesMode {
                                    // Update the places array with the new places
                                    places.append(contentsOf: newPlaces)
                                    
                                    // Only trigger animation for truly new places
                                    let newPlaceIds = Set(newPlaces.map { $0.placeId })
                                    let trulyNewPlaces = !newPlaceIds.isSubset(of: self.existingPlaceIds)
                                    self.existingPlaceIds.formUnion(newPlaceIds)
                                    
                                    // Trigger animation for new places only if there are truly new places
                                    newPlacesLoaded = trulyNewPlaces
                                    
                                    // Reset the animation flag after a short delay
                                    if newPlacesLoaded {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                            guard let self = self else { return }
                                            self.newPlacesLoaded = false
                                        }
                                    }
                                    
                                    // Trigger UI update
                                    objectWillChange.send()
                                    
                                    // Show subtle notification about the update
                                    showNotificationMessage("Found \(newPlaces.count) more \(category) places")
                                }
                            } else {
                                logger.notice("No new places found for category \(category)")
                            }
                        } else {
                            // If we don't have an all categories cache yet, create one from the specific category places
                            // This is a fallback and shouldn't normally happen
                            logger.notice("No all categories cache exists, creating one from specific category places")
                            allCategoriesCache = specificCategoryPlaces
                            lastCachedCenter = lastQueriedCenter
                            logCacheStatus(operation: "CREATE", details: "Created all categories cache with \(specificCategoryPlaces.count) places")
                            
                            // Update the viewport cache as well
                            let viewportKey = viewportCacheKey(for: region.center)
                            viewportCache[viewportKey] = specificCategoryPlaces
                            logCacheStatus(operation: "CREATE", details: "Created viewport cache with \(specificCategoryPlaces.count) places")
                            
                            // Update the displayed places
                            places = specificCategoryPlaces
                            
                            // Update tracking of existing place IDs
                            let newPlaceIds = Set(specificCategoryPlaces.map { $0.placeId })
                            let trulyNewPlaces = !newPlaceIds.isSubset(of: self.existingPlaceIds)
                            self.existingPlaceIds = newPlaceIds
                            
                            // Trigger animation for new places only if there are truly new places
                            newPlacesLoaded = trulyNewPlaces
                            
                            // Reset the animation flag after a short delay
                            if newPlacesLoaded {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                    guard let self = self else { return }
                                    self.newPlacesLoaded = false
                                }
                            }
                            
                            // Trigger UI update
                            objectWillChange.send()
                        }
                        
                        // Show subtle notification about the update
                        showNotificationMessage("Updated with \(specificCategoryPlaces.count) places")
                    }
                } catch {
                    await MainActor.run {
                        logger.error("Error fetching specific category places: \(error.localizedDescription)")
                        
                        // Only show error notification if we don't have any places to display
                        if places.isEmpty {
                            showNotificationMessage("Error loading places: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else if isAddingCategory && isAllCategoriesMode {
            // If we're switching to "All" categories mode, make a background request for all categories
            Task { [weak self] in
                guard let self = self else { return }
                
                logger.notice("Making background request for all categories")
                
                do {
                    // Fetch all categories
                    let allCategoriesPlaces = try await fetchPlaces(
                        center: region.center,
                        region: self.region,
                        categories: categoryEmojis
                    )
                    
                    await MainActor.run {
                        logger.notice("Received \(allCategoriesPlaces.count) places for all categories")
                        
                        // Update the all categories cache
                        allCategoriesCache = allCategoriesPlaces
                        lastCachedCenter = lastQueriedCenter
                        logCacheStatus(operation: "UPDATE", details: "Updated all categories cache with \(allCategoriesPlaces.count) places")
                        
                        // Update the viewport cache as well
                        let viewportKey = viewportCacheKey(for: region.center)
                        viewportCache[viewportKey] = allCategoriesPlaces
                        logCacheStatus(operation: "UPDATE", details: "Updated viewport cache with \(allCategoriesPlaces.count) places")
                        
                        // If we're still in "All" mode, update the displayed places
                        if isAllCategoriesMode {
                            places = allCategoriesPlaces
                            
                            // Update tracking of existing place IDs
                            let newPlaceIds = Set(allCategoriesPlaces.map { $0.placeId })
                            let trulyNewPlaces = !newPlaceIds.isSubset(of: self.existingPlaceIds)
                            self.existingPlaceIds = newPlaceIds
                            
                            // Trigger animation for new places only if there are truly new places
                            newPlacesLoaded = trulyNewPlaces
                            
                            // Reset the animation flag after a short delay
                            if newPlacesLoaded {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                    guard let self = self else { return }
                                    self.newPlacesLoaded = false
                                }
                            }
                            
                            // Trigger UI update
                            objectWillChange.send()
                            
                            // Show subtle notification about the update
                            showNotificationMessage("Updated with \(allCategoriesPlaces.count) places")
                        }
                    }
                } catch {
                    await MainActor.run {
                        logger.error("Error fetching all categories places: \(error.localizedDescription)")
                        
                        // Only show error notification if we don't have any places to display
                        if places.isEmpty {
                            showNotificationMessage("Error loading places: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func toggleFavoritesFilter() {
        // Provide haptic feedback
        HapticsManager.shared.prepareGenerators()
        
        showFavoritesOnly.toggle()
        
        // Provide appropriate feedback based on state
        if showFavoritesOnly {
            // Stronger feedback when enabling favorites
            HapticsManager.shared.mediumImpact(intensity: 0.9)
        } else {
            // Lighter feedback when disabling
            HapticsManager.shared.lightImpact(intensity: 0.7)
        }
        
        // Show notification with haptic feedback
        if showFavoritesOnly {
            if isAllCategoriesMode {
                showNotificationMessage("Showing all favorites")
            } else {
                let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(
                    separator: ", "
                )
                showNotificationMessage(
                    "Showing favorites in: \(categoryNames)"
                )
            }
        } else {
            if selectedCategories.isEmpty || isAllCategoriesMode {
                showNotificationMessage("Showing all places")
            } else {
                showNotificationMessage("Filter removed")
            }
        }
        
        // Favorites filtering is always done locally since it's based on user preferences
        // No need to fetch from the network, just update the UI
        logCacheStatus(operation: "FILTER", details: "Applying favorites filter locally: \(showFavoritesOnly ? "ON" : "OFF")")
        
        // Trigger UI update to reflect the filter change
        objectWillChange.send()
    }
    
    func categoryName(for category: String) -> String {
        // If it's an emoji, just return it
        if CategoryMappings.emojiToKey[category] != nil {
            return category
        }
        
        // If it's a key (as string), try to get the emoji
        if let key = Int(category), let emoji = CategoryMappings.getEmojiForKey(key) {
            return emoji
        }
        
        // Default fallback
        return category
    }
    
    func categoryEmoji(for category: String) -> String {
        // If it's already an emoji, return it
        if CategoryMappings.emojiToKey[category] != nil {
            return category
        }
        
        // If it's a key (as string), try to get the emoji
        if let key = Int(category), let emoji = CategoryMappings.getEmojiForKey(key) {
            return emoji
        }
        
        // Default fallback
        return "📍"
    }
    
    func isFavorite(placeId: String) -> Bool {
        // Get a direct reference to UserPreferences to ensure we have the latest data
        let userPrefs = ServiceContainer.shared.userPreferences
        
        return userPrefs.isFavorite(placeId: placeId)
    }
    
    func addFavorite(_ place: Place) {
        // Get direct reference to UserPreferences
        let userPrefs = ServiceContainer.shared.userPreferences
        
        // Add to favorites
        userPrefs.addFavorite(place)
        
        // Debug: Print favorites after change
        print("After adding favorite for \(place.name):")
        userPrefs.printFavorites()
        
        // Trigger UI update
        objectWillChange.send()
        
        // Provide haptic feedback
        HapticsManager.shared.successSequence()
        
        // Show notification to confirm action
        showNotificationMessage("\(place.name) added to favorites")
    }
    
    func removeFavorite(placeId: String) {
        // Get direct reference to UserPreferences
        let userPrefs = ServiceContainer.shared.userPreferences
        
        // Get the place name for the notification
        let placeName = places.first(where: { $0.placeId == placeId })?.name ?? "Place"
        
        // Remove from favorites
        userPrefs.removeFavorite(placeId: placeId)
        
        // Debug: Print favorites after change
        print("After removing favorite for \(placeName):")
        userPrefs.printFavorites()
        
        // Trigger UI update
        objectWillChange.send()
        
        // Provide haptic feedback
        HapticsManager.shared.mediumImpact(intensity: 0.7)
        
        // Show notification to confirm action
        showNotificationMessage("\(placeName) removed from favorites")
    }
    
    func toggleFavorite(for place: Place) {
        // Get direct reference to UserPreferences
        let userPrefs = ServiceContainer.shared.userPreferences
        
        let wasAlreadyFavorite = userPrefs.isFavorite(placeId: place.placeId)
        
        // Update UserPreferences directly
        if wasAlreadyFavorite {
            removeFavorite(placeId: place.placeId)
        } else {
            addFavorite(place)
        }
    }
    
    func getRating(for placeId: String) -> Int? {
        // Get a direct reference to UserPreferences to ensure we have the latest data
        let userPrefs = ServiceContainer.shared.userPreferences
        
        // Only return the user's local rating
        return userPrefs.getRating(for: placeId)
    }
    
    func ratePlace(placeId: String, rating: Int) {
        logger.info("📝 INFO: MapViewModel.ratePlace called for placeId: \(placeId) with rating: \(rating)")
        
        // Get direct reference to UserPreferences
        let userPrefs = ServiceContainer.shared.userPreferences
        
        // Update UserPreferences directly
        userPrefs.ratePlace(placeId: placeId, rating: rating)
        
        // Trigger UI update
        objectWillChange.send()
        
        logger.info("📝 INFO: MapViewModel.ratePlace completed")
    }
    
    // Helper method to save the current filter state
    private func saveCurrentFilterState() -> [String: Any] {
        return [
            "selectedCategories": Array(selectedCategories),
            "isAllCategoriesMode": isAllCategoriesMode,
            "showFavoritesOnly": showFavoritesOnly,
            "selectedPriceLevels": Array(selectedPriceLevels),
            "showOpenNowOnly": showOpenNowOnly,
            "minimumRating": minimumRating,
            "useLocalRatings": useLocalRatings
        ]
    }
    
    // Helper method to restore the filter state
    private func restoreFilterState(_ state: [String: Any]) {
        if let selectedCategories = state["selectedCategories"] as? [String] {
            self.selectedCategories = Set(selectedCategories)
        }
        
        if let isAllCategoriesMode = state["isAllCategoriesMode"] as? Bool {
            self.isAllCategoriesMode = isAllCategoriesMode
        }
        
        if let showFavoritesOnly = state["showFavoritesOnly"] as? Bool {
            self.showFavoritesOnly = showFavoritesOnly
        }
        
        if let selectedPriceLevels = state["selectedPriceLevels"] as? [Int] {
            self.selectedPriceLevels = Set(selectedPriceLevels)
        }
        
        if let showOpenNowOnly = state["showOpenNowOnly"] as? Bool {
            self.showOpenNowOnly = showOpenNowOnly
        }
        
        if let minimumRating = state["minimumRating"] as? Int {
            self.minimumRating = minimumRating
        }
        
        if let useLocalRatings = state["useLocalRatings"] as? Bool {
            self.useLocalRatings = useLocalRatings
        }
    }
    
    func onRegionChange(newCenter: CoordinateWrapper) {
        // Cancel any existing debounce task
        regionChangeDebounceTask?.cancel()
        
        // Calculate distance from last query
        let distanceFromLastQuery = distance(
            from: lastQueriedCenter.coordinate,
            to: newCenter.coordinate
        )
        
        // Show the search button for very large distances (over 5km)
        // This gives users a manual option for big jumps on the map
        if distanceFromLastQuery > 5000 {
            showSearchHereButton = true
        } else {
            showSearchHereButton = false
        }
        
        // Check if we have a cache for this viewport
        let viewportKey = viewportCacheKey(for: newCenter.coordinate)
        let hasViewportCache = viewportCache[viewportKey] != nil && !viewportCache[viewportKey]!.isEmpty
        
        if hasViewportCache {
            logCacheStatus(operation: "CHECK", details: "Found viewport cache for \(viewportKey)")
        }
        
        // Only fetch new places if we've moved a significant distance (more than 500m) and don't have a cache
        if distanceFromLastQuery > 500 && !hasViewportCache {
            // Create a new debounce task that won't block the UI
            regionChangeDebounceTask = Task { [weak self] in
                guard let self = self else { return }
                
                // Wait for the debounce interval
                try? await Task.sleep(nanoseconds: UInt64(regionChangeDebounceInterval * 1_000_000_000))
                
                // If this task was cancelled during the sleep, exit
                if Task.isCancelled {
                    return
                }
                
                // Update the last queried center to the current region center
                await MainActor.run {
                    self.lastQueriedCenter = newCenter
                    
                    // Only hide the search button for smaller distances
                    if distanceFromLastQuery <= 5000 {
                        self.showSearchHereButton = false
                    }
                    
                    // Show a subtle notification only for larger movements
                    if distanceFromLastQuery > 1000 {
                        self.showNotificationMessage("Updating places...")
                    }
                }
                
                // Fetch places at the new location in a non-blocking way
                Task {
                    try? await self.fetchAndUpdatePlaces()
                }
            }
        } else if distanceFromLastQuery > 500 && hasViewportCache {
            // Use the cached data for this viewport
            regionChangeDebounceTask = Task { [weak self] in
                guard let self = self else { return }
                
                // Wait for a shorter debounce interval since we're using cache
                try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
                
                // If this task was cancelled during the sleep, exit
                if Task.isCancelled {
                    return
                }
                
                // Update the last queried center to the current region center
                await MainActor.run {
                    self.lastQueriedCenter = newCenter
                    
                    // Only hide the search button for smaller distances
                    if distanceFromLastQuery <= 5000 {
                        self.showSearchHereButton = false
                    }
                    
                    // Use the cached places
                    let cachedPlaces = self.viewportCache[viewportKey]!
                    self.places = cachedPlaces
                    
                    // If we're in all categories mode, update the all categories cache
                    if self.isAllCategoriesMode {
                        self.allCategoriesCache = cachedPlaces
                        self.lastCachedCenter = newCenter
                        self.logCacheStatus(operation: "UPDATE", details: "Updated all categories cache from viewport cache")
                    }
                    
                    // Show a subtle notification for larger movements
                    if distanceFromLastQuery > 1000 {
                        self.showNotificationMessage("Loaded places from cache")
                    }
                    
                    self.logCacheStatus(operation: "USE", details: "Used viewport cache for region change")
                }
            }
        } else {
            // For small movements, just update the center without fetching
            lastQueriedCenter = newCenter
        }
    }
    
    // Add a method to clear the cache
    func clearCache() {
        allCategoriesCache = []
        lastCachedCenter = nil
        viewportCache = [:]
        logCacheStatus(operation: "CLEAR", details: "Manually cleared all caches")
    }
    
    // Keep the searchHere method for manual searches
    func searchHere() {
        // Update the last queried center to the current region center
        lastQueriedCenter = CoordinateWrapper(region.center)
        
        // Hide the search button
        showSearchHereButton = false
        
        // Show notification that we're searching
        showNotificationMessage("Searching in this area...")
        
        // Check if we have a viewport cache for this location
        let viewportKey = viewportCacheKey(for: region.center)
        let hasViewportCache = viewportCache[viewportKey] != nil && !viewportCache[viewportKey]!.isEmpty
        
        // Use a non-blocking task for all operations
        Task { [weak self] in
            guard let self = self else { return }
            
            if hasViewportCache {
                await MainActor.run {
                    logCacheStatus(operation: "USE", details: "Using viewport cache for manual search")
                    
                    // Use the cached places for this viewport
                    places = viewportCache[viewportKey]!
                    
                    // If we're in all categories mode, update the all categories cache
                    if isAllCategoriesMode {
                        allCategoriesCache = places
                        lastCachedCenter = lastQueriedCenter
                        logCacheStatus(operation: "UPDATE", details: "Updated all categories cache from viewport cache")
                    }
                    
                    // Show notification
                    showNotificationMessage("Loaded places from cache")
                    
                    // Trigger UI update
                    objectWillChange.send()
                }
            } else {
                // Fetch places at the new location with a dynamic radius based on the current viewport
                try? await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    func onAppear() {
        // Only request location if we don't already have places loaded
        if places.isEmpty {
            // Request a fresh location update
            locationManager.requestLocation()
            
            // Try to use the user's location if available
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Wait a short time for location to update
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                if let userLocation = locationManager.location {
                    print("User location found: \(userLocation.coordinate)")
                    
                    // Create a new region centered on the user's location
                    let newRegion = MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                    
                    // Update the region - this will trigger the onChange handler in ContentView
                    self.region = newRegion
                    
                    // Notify about region change
                    onRegionDidChange?(newRegion)
                    
                    // Update the last queried center to match the new region
                    lastQueriedCenter = CoordinateWrapper(userLocation.coordinate)
                    
                    // Only fetch places if we don't already have places loaded and we're not already fetching
                    if self.places.isEmpty && !self.isFetchingPlaces {
                        logger.notice("Fetching places on appear (user location available)")
                        try await self.fetchAndUpdatePlaces()
                    } else {
                        logger.notice("Skipping fetch on appear - places already loaded or fetch in progress")
                    }
                    self.shouldCenterOnLocation = false
                    
                    // Explicitly trigger UI update
                    objectWillChange.send()
                } else {
                    print("User location not available, using default location")
                    // Request location authorization if not determined yet
                    if locationManager.authorizationStatus == .notDetermined {
                        locationManager.requestWhenInUseAuthorization()
                    } else if locationManager.authorizationStatus == .authorizedWhenInUse || 
                              locationManager.authorizationStatus == .authorizedAlways {
                        // Start location updates to get the current location
                        locationManager.startUpdatingLocation()
                    }
                    
                    // Fetch places at the default location only if we don't already have places and we're not already fetching
                    if self.places.isEmpty && !self.isFetchingPlaces {
                        logger.notice("Fetching places on appear (default location)")
                        try await self.fetchAndUpdatePlaces()
                    } else {
                        logger.notice("Skipping fetch on appear - places already loaded or fetch in progress")
                    }
                }
            }
        } else {
            // If we already have places, just trigger a UI update
            logger.notice("Places already loaded on appear, skipping fetch")
            objectWillChange.send()
        }
    }
    
    func recenterMap() {
        // Force refresh location before centering
        locationManager.requestLocation()
        
        // Show a loading notification
        showNotificationMessage("Finding your location...")
        
        // Provide haptic feedback for the request
        HapticsManager.shared.lightImpact()
        
        // Use a task to wait for location update
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Wait a short time for location to update
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if let userLocation = locationManager.location {
                // Provide haptic feedback for success
                HapticsManager.shared.mediumImpact()
                
                print("Recentering map to user location: \(userLocation.coordinate)")
                
                // Update the region to the user's location with a closer zoom level
                let newRegion = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                
                // Update the region - this will trigger the onChange handler in ContentView
                self.region = newRegion
                
                // Notify about region change
                onRegionDidChange?(newRegion)
                
                // Update the last queried center to match the new region
                lastQueriedCenter = CoordinateWrapper(userLocation.coordinate)
                
                // Hide the search button since we're at the user's location
                showSearchHereButton = false
                
                // Fetch places at the new location
                try await self.fetchAndUpdatePlaces()
                
                // Show notification
                showNotificationMessage("Centered on your location")
                
                // Explicitly trigger UI update
                objectWillChange.send()
            } else {
                // Provide error feedback if location is not available
                HapticsManager.shared.errorSequence()
                
                // Request location authorization if not determined yet
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                    showNotificationMessage("Requesting location access...")
                } else if locationManager.authorizationStatus == .authorizedWhenInUse || 
                          locationManager.authorizationStatus == .authorizedAlways {
                    // Start location updates to get the current location
                    locationManager.startUpdatingLocation()
                    showNotificationMessage("Finding your location...")
                }
            }
        }
    }
    
    // Synchronous wrapper for the async fetchAndUpdatePlaces method
    func retryFetchPlaces() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await self.fetchAndUpdatePlaces()
        }
    }
    
    @MainActor
    func fetchAndUpdatePlaces() async throws {
        // Cancel any existing debounce task
        fetchDebounceTask?.cancel()
        
        // Create a new debounce task
        fetchDebounceTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Check if we're already fetching or if we've fetched recently
            if isFetchingPlaces {
                logger.notice("Fetch already in progress, skipping duplicate request")
                return
            }
            
            let now = Date()
            if now.timeIntervalSince(lastFetchTime) < fetchDebounceInterval {
                // Wait for the debounce interval
                let waitTime = fetchDebounceInterval - now.timeIntervalSince(lastFetchTime)
                logger.notice("Debouncing fetch request for \(waitTime) seconds")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                
                // If this task was cancelled during the sleep, exit
                if Task.isCancelled {
                    return
                }
            }
            
            // Mark that we're starting a fetch
            isFetchingPlaces = true
            lastFetchTime = Date()
            
            // Instead of showing a loading indicator that might block the UI,
            // just show a subtle notification that data is being fetched
            await MainActor.run {
                // Show a subtle notification that we're fetching data
                showNotificationMessage("Updating places...")
            }
            
            error = nil
            showError = false
            
            // Cancel any previous requests before starting a new one
            backendService.cancelPlacesRequests()

            do {
                // Only include categories that are currently selected
                let activeCategories: [String]
                if isAllCategoriesMode {
                    // If in "All" mode, include all categories
                    activeCategories = categoryEmojis
                } else {
                    // Otherwise, only include the selected categories
                    activeCategories = Array(selectedCategories)
                }
                
                // Log the active categories for debugging
                logger.notice("Fetching places with active categories: \(activeCategories.joined(separator: ", "))")
                
                let fetchedPlaces = try await fetchPlaces(
                    center: region.center,
                    region: self.region,
                    categories: activeCategories
                )
                
                // Update UI on the main actor but without blocking
                await MainActor.run {
                    // Log the fetched places
                    logger.notice("Received \(fetchedPlaces.count) places from the service")
                    if let firstPlace = fetchedPlaces.first {
                        logger.notice("First place: id=\(firstPlace.placeId), name=\(firstPlace.name), category=\(firstPlace.category), coordinates=(\(firstPlace.coordinate.latitude), \(firstPlace.coordinate.longitude))")
                    }
                    
                    // Log category distribution
                    let categoryDistribution = Dictionary(grouping: fetchedPlaces, by: { $0.category })
                        .mapValues { $0.count }
                        .sorted { $0.value > $1.value }
                    
                    logger.notice("Category distribution in fetched places:")
                    for (category, count) in categoryDistribution {
                        logger.notice("  - \(category.isEmpty ? "[empty]" : category): \(count) places")
                    }
                    
                    // Check if any places have empty categories and log them
                    let placesWithEmptyCategory = fetchedPlaces.filter { $0.category.isEmpty }
                    if !placesWithEmptyCategory.isEmpty {
                        logger.warning("Found \(placesWithEmptyCategory.count) places with empty categories")
                        for place in placesWithEmptyCategory.prefix(3) {
                            logger.warning("Place with empty category: \(place.name), id=\(place.placeId)")
                        }
                    }
                    
                    // Check if any places have categories that don't match our selected categories
                    let selectedCategoryNames = selectedCategories.isEmpty ? 
                        Set(categoryEmojis) : 
                        selectedCategories
                    
                    let placesWithUnmatchedCategory = fetchedPlaces.filter { !selectedCategoryNames.contains($0.category) }
                    if !placesWithUnmatchedCategory.isEmpty {
                        logger.warning("Found \(placesWithUnmatchedCategory.count) places with categories not in selected categories")
                        logger.warning("Selected categories: \(selectedCategoryNames.joined(separator: ", "))")
                        for place in placesWithUnmatchedCategory.prefix(3) {
                            logger.warning("Place with unmatched category: \(place.name), category=\(place.category)")
                        }
                    }
                    
                    // Update places and trigger animation flag only for new places
                    let newPlaceIds = Set(fetchedPlaces.map { $0.placeId })
                    let trulyNewPlaces = !newPlaceIds.isSubset(of: self.existingPlaceIds)
                    
                    self.places = fetchedPlaces
                    // Only set newPlacesLoaded to true if there are truly new places
                    self.newPlacesLoaded = trulyNewPlaces
                    
                    // Update our tracking of existing place IDs
                    self.existingPlaceIds = newPlaceIds
                    
                    // Store in viewport cache
                    let viewportKey = viewportCacheKey(for: region.center)
                    viewportCache[viewportKey] = fetchedPlaces
                    logCacheStatus(operation: "UPDATE", details: "Added \(fetchedPlaces.count) places to viewport cache for \(viewportKey)")
                    
                    // If we fetched all categories, update the all categories cache
                    if isAllCategoriesMode {
                        allCategoriesCache = fetchedPlaces
                        lastCachedCenter = lastQueriedCenter
                        logCacheStatus(operation: "UPDATE", details: "Updated all categories cache with \(self.allCategoriesCache.count) places")
                    }
                    
                    // Reset the animation flag after a short delay
                    if self.newPlacesLoaded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            guard let self = self else { return }
                            self.newPlacesLoaded = false
                        }
                    }
                    
                    // Log the places after assignment
                    logger.notice("Updated self.places with \(self.places.count) places")
                    logger.notice("Filtered places count: \(self.filteredPlaces.count)")
                    
                    // If we got zero places, provide feedback
                    if fetchedPlaces.isEmpty {
                        // Provide haptic feedback for no results
                        HapticsManager.shared.notification(type: .warning)
                        
                        // Show notification
                        showNotificationMessage("No places found in this area")
                    } else {
                        // Show a subtle notification that places were updated
                        showNotificationMessage("Updated \(fetchedPlaces.count) places")
                    }
                    
                    // Turn off loading state
                    isFetchingPlaces = false
                }
            } catch let networkError as NetworkError {
                await MainActor.run {
                    self.error = networkError
                    
                    // Handle specific error types
                    if case .noResults(let placeType) = networkError {
                        // Provide haptic feedback for no results
                        HapticsManager.shared.notification(type: .warning)
                        
                        // Show notification
                        showNotificationMessage("No \(categoryName(for: placeType)) places found in this area")
                        
                        // Don't show error alert for no results
                        self.showError = false
                    } else {
                        // Only show error alert if it's not a cancelled request
                        self.showError = networkError.shouldShowAlert
                        
                        // Provide error feedback for non-cancelled requests
                        if networkError.shouldShowAlert {
                            HapticsManager.shared.errorSequence()
                            
                            // Show a notification instead of a blocking alert
                            showNotificationMessage("Error: \(networkError.localizedDescription)")
                        }
                    }
                    
                    print("Network error: \(networkError.localizedDescription)")
                    
                    // Turn off loading state
                    isFetchingPlaces = false
                }
            } catch {
                await MainActor.run {
                    self.error = .unknownError(error)
                    
                    // Show a notification instead of a blocking alert
                    showNotificationMessage("Error: \(error.localizedDescription)")
                    
                    print("Unknown error: \(error.localizedDescription)")
                    
                    // Turn off loading state
                    isFetchingPlaces = false
                }
            }
            
            // Mark that we've finished fetching
            isFetchingPlaces = false
        }
    }
    
    /// Fetches places from the backend service using async/await
    /// - Parameters:
    ///   - center: The center coordinate to search around
    ///   - region: Optional region to determine search radius
    ///   - categories: Categories to search for
    /// - Returns: Array of places
    /// - Throws: NetworkError if the request fails
    private func fetchPlaces(center: CLLocationCoordinate2D, region: MKCoordinateRegion?, categories: [String]) async throws -> [Place] {
        // Check if we're in "all categories" mode or if all categories are selected
        let isAllCategoriesSelected = isAllCategoriesMode || categories.count == CategoryMappings.allEmojis.count
        
        if isAllCategoriesSelected {
            // If all categories are selected, don't send any categories (API defaults to all)
            logger.debug("Fetching places with all categories")
            return try await backendService.fetchPlaces(
                center: center,
                region: region,
                categories: nil,
                showOpenNowOnly: showOpenNowOnly
            )
        } else {
            // Log the emojis being used
            logger.debug("Fetching places with emojis: \(categories)")
            
            // Log the keys being used
            let keys = categories.compactMap { CategoryMappings.getKeyForEmoji($0) }
            logger.debug("Using keys: \(keys)")
            
            // Call the backend service
            return try await backendService.fetchPlaces(
                center: center,
                region: region,
                categories: categories,
                showOpenNowOnly: showOpenNowOnly
            )
        }
    }
    
    private func updateRegion(to coordinate: CLLocationCoordinate2D) {
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        region = newRegion
        lastQueriedCenter = CoordinateWrapper(coordinate)
        
        // Notify about region change
        onRegionDidChange?(newRegion)
    }
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(
            latitude: from.latitude,
            longitude: from.longitude
        )
        let location2 = CLLocation(
            latitude: to.latitude,
            longitude: to.longitude
        )
        return location1.distance(from: location2)
    }
    
    func showNotificationMessage(_ message: String) {
        notificationMessage = message
        showNotification = true
        
        // Hide notification after 10 seconds
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if self.notificationMessage == message {
                self.showNotification = false
            }
        }
    }
    
    func toggleAllCategories() {
        // Provide haptic feedback
        HapticsManager.shared.prepareGenerators()
        
        // If "All" is already selected, don't allow toggling it off directly
        // This prevents the case where no categories would be selected
        if isAllCategoriesMode {
            // Just provide feedback to indicate the action was received but not needed
            HapticsManager.shared.lightImpact(intensity: 0.4)
            
            // Show notification to inform the user
            if showFavoritesOnly {
                showNotificationMessage("Already showing all favorites")
            } else {
                showNotificationMessage("Already showing all categories")
            }
            return
        }
        
        // If we get here, we're switching from specific categories to "All" mode
        isAllCategoriesMode = true
        
        // Select all categories
        selectedCategories = Set(categoryEmojis)
        HapticsManager.shared.mediumImpact(intensity: 0.8)
        
        // Show appropriate notification based on favorites filter
        if showFavoritesOnly {
            showNotificationMessage("Showing favorites in all categories")
        } else {
            showNotificationMessage("Showing all categories")
        }
        
        // Check if we have a viewport cache for the current location
        let viewportKey = viewportCacheKey(for: lastQueriedCenter.coordinate)
        let hasViewportCache = viewportCache[viewportKey] != nil && !viewportCache[viewportKey]!.isEmpty
        
        // Switching to "All" is broadening the filter, so we should use cache if available
        if hasViewportCache {
            logCacheStatus(operation: "USE", details: "Using viewport cache for switching to All categories")
            
            // Use the cached places for this viewport
            places = viewportCache[viewportKey]!
            
            // Update the all categories cache
            allCategoriesCache = places
            lastCachedCenter = lastQueriedCenter
            
            // Trigger UI update
            objectWillChange.send()
            
            logCacheStatus(operation: "UPDATE", details: "Updated all categories cache from viewport cache")
        } else {
            // If no viewport cache is available, fetch new data
            logCacheStatus(operation: "MISS", details: "No viewport cache available for All categories")
            
            // Since we're using @MainActor, this will be dispatched to the main thread
            Task { [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    // Function to recommend a random place based on current filters
    func recommendRandomPlace() {
        // Get the filtered places based on current selection
        let availablePlaces = filteredPlaces
        
        // Check if there are any places to recommend
        if availablePlaces.isEmpty {
            // Provide error haptic feedback
            HapticsManager.shared.errorSequence()
            
            // Create a descriptive message based on active filters
            var message = "No places to recommend"
            
            if showFavoritesOnly {
                message += " in your favorites"
                
                if !selectedCategories.isEmpty && !isAllCategoriesMode {
                    let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(separator: ", ")
                    message += " matching: \(categoryNames)"
                }
            } else if !selectedCategories.isEmpty && !isAllCategoriesMode {
                let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(separator: ", ")
                message += " matching: \(categoryNames)"
            }
            
            // Add price filter info if active
            if selectedPriceLevels.count < 4 {
                let priceSymbols = selectedPriceLevels.sorted().map { String(repeating: "$", count: $0) }.joined(separator: ", ")
                message += " with price \(priceSymbols)"
            }
            
            // Add open now info if active
            if showOpenNowOnly {
                message += " that are open now"
            }
            
            // Add rating info if active
            if minimumRating > 0 {
                message += " with \(minimumRating)+ star rating"
            }
            
            showNotificationMessage(message)
            return
        }
        
        // Select a random place from the filtered list
        if let randomPlace = availablePlaces.randomElement() {
            // Provide haptic feedback
            HapticsManager.shared.heavyImpact(intensity: 1.0)
            
            // Update the selected place to show its details
            selectedPlace = randomPlace
            
            // Show a notification
            let categoryName = categoryName(for: randomPlace.category)
            var message = "Recommended: \(randomPlace.name) (\(categoryName))"
            
            // Add favorite indicator if it's a favorite
            if userPreferences.isFavorite(placeId: randomPlace.placeId) {
                message += " ⭐️"
            }
            
            showNotificationMessage(message)
            
            // Update the map region to center on this place
            updateRegion(to: randomPlace.coordinate)
            
            // Notify about region change
            onRegionDidChange?(region)
        }
    }
    
    func openAppSettings() {
        locationManager.openAppSettings()
    }
    
    func continueWithoutLocation() {
        showLocationPermissionView = false
        // Use default location (already set in init)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
        }
        showNotificationMessage("Using default location. Some features may be limited.")
    }
    
    // Cancel all pending requests when the view model is deallocated
    deinit {
        // Cancel the subscription when the view model is deallocated
        updateSubscription?.cancel()
        
        // Cancel all pending requests when the view model is deallocated
        backendService.cancelPlacesRequests()
    }
    
    // New method to refresh places by clearing the cache and fetching fresh data
    func refreshPlaces() {
        // Clear the cache
        cache.clearPlacesCache()
        
        // Fetch fresh data
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
        }
        
        // Show notification
        showNotificationMessage("Refreshing places...")
    }
    
    // New method to refresh filtered places without fetching new data
    func refreshFilteredPlaces() {
        logger.info("📝 INFO: Refreshing filtered places after favorite/rating changes")
        
        // Force UI refresh to update filtered places
        objectWillChange.send()
        
        // If we're showing favorites only, we need to ensure the UI updates
        if showFavoritesOnly {
            // Show notification to confirm the update
            showNotificationMessage("Favorites updated")
        }
        
        // If we're filtering by ratings, we need to ensure the UI updates
        if minimumRating > 0 && useLocalRatings {
            // Show notification to confirm the update
            showNotificationMessage("Ratings updated")
        }
    }
    
    func requestUserLocation() {
        // Check if location services are enabled using the class method
        // This needs to be called off the main thread to avoid UI unresponsiveness
        Task {
            let locationServicesEnabled = await Task.detached {
                CLLocationManager.locationServicesEnabled()
            }.value
            
            await MainActor.run {
                if locationServicesEnabled {
                    // Start updating location
                    locationManager.startUpdatingLocation()
                    showNotificationMessage("Finding your location...")
                } else {
                    // Show notification
                    showNotificationMessage("Unable to find your location")
                }
            }
        }
    }
}
