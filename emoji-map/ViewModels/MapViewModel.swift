//
//  MapViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit
import CoreLocation

// Thread-safe actor for managing shared state
@MainActor
class MapViewModel: ObservableObject {
    let categories = [
        ("🍕", "pizza", "restaurant"),
        ("🍺", "beer", "bar"),
        ("🍣", "sushi", "restaurant"),
        ("☕️", "coffee", "cafe"),
        ("🍔", "burger", "restaurant"),
        ("🌮", "mexican", "restaurant"),
        ("🍜", "ramen", "restaurant"),
        ("🥗", "salad", "restaurant"),
        ("🍦", "dessert", "restaurant"),
        ("🍷", "wine", "bar"),
        ("🍲", "asian_fusion", "restaurant"),
        ("🥪", "sandwich", "restaurant")
    ]
    
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
    
    private let googlePlacesService: GooglePlacesServiceProtocol
    private let userPreferences: UserPreferences
    private var shouldCenterOnLocation = true
    
    // Make locationManager accessible to other views
    let locationManager: LocationManager
    
    // Public getter for userPreferences
    var preferences: UserPreferences {
        return userPreferences
    }
    
    // Computed property to check if all categories are selected
    var areAllCategoriesSelected: Bool {
        selectedCategories.count == categories.count && categories
            .allSatisfy { selectedCategories.contains($0.1) }
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
        
        // Filter by favorites if enabled
        if showFavoritesOnly {
            filtered = filtered.filter { place in
                userPreferences.isFavorite(placeId: place.placeId)
            }
        }
        
        // Filter by categories
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { place in
                selectedCategories.contains(place.category)
            }
        }
        
        // Filter by price level
        if selectedPriceLevels.count < 4 { // If not all price levels are selected
            filtered = filtered.filter { place in
                if let priceLevel = place.priceLevel {
                    return selectedPriceLevels.contains(priceLevel)
                }
                return true // Include places with no price level information
            }
        }
        
        // Filter by open now status
        if showOpenNowOnly {
            filtered = filtered.filter { place in
                place.openNow == true
            }
        }
        
        // Filter by minimum rating
        if minimumRating > 0 {
            if useLocalRatings {
                // Use local user ratings
                filtered = filtered.filter { place in
                    if let rating = userPreferences.getRating(for: place.placeId) {
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
        }
        
        return filtered
    }
    
    init(
        googlePlacesService: GooglePlacesServiceProtocol,
        userPreferences: UserPreferences = UserPreferences()
    ) {
        self.googlePlacesService = googlePlacesService
        self.userPreferences = userPreferences
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
        self.selectedCategories = Set(categories.map { $0.1 })
        
        // Initialize isAllCategoriesMode to true since we're starting with all categories selected
        self.isAllCategoriesMode = true
        
        // Check for configuration issues
        checkConfiguration()
        
        // Explicitly request location authorization if not determined
        if locationManager.authorizationStatus == .notDetermined {
            print("Requesting location authorization during initialization")
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Setup location updates
        setupLocationUpdates()
        
        // Debug: Print current favorites on initialization
        print("MapViewModel initialized")
        userPreferences.printFavorites()
    }
    
    private func checkConfiguration() {
        if Configuration.isUsingMockKey {
            showConfigWarning = true
            configWarningMessage = "Using mock API key. Data shown is not from real API."
        }
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
        
        // Ensure location updates are handled on the main actor
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            
            print("Received location update: \(location.coordinate)")
            
            // Since we're using @MainActor, this will be dispatched to the main thread
            if self.shouldCenterOnLocation {
                print("Centering on user location")
                // Capture self weakly in the Task to prevent retain cycles
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
    
    func toggleCategory(_ category: String) {
        // Provide haptic feedback
        HapticsManager.shared.prepareGenerators()
        
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
        } else {
            // Normal toggle behavior when "All" is not selected
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
                // Lighter feedback for deselection
                HapticsManager.shared.lightImpact(intensity: 0.6)
                
                // If we removed a category and now no categories are selected, set isAllCategoriesMode to false
                if selectedCategories.isEmpty {
                    isAllCategoriesMode = false
                }
            } else {
                selectedCategories.insert(category)
                // Stronger feedback for selection
                HapticsManager.shared.mediumImpact(intensity: 0.8)
                
                // If we added a category and now all categories are selected, set isAllCategoriesMode to true
                if areAllCategoriesSelected {
                    isAllCategoriesMode = true
                }
            }
        }
        
        // Update notification if favorites filter is active
        if showFavoritesOnly {
            if selectedCategories.isEmpty {
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
        
        // Since we're using @MainActor, this will be dispatched to the main thread
        Task { [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
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
            if selectedCategories.isEmpty {
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
            if selectedCategories.isEmpty {
                showNotificationMessage("Showing all places")
            } else {
                showNotificationMessage("Filter removed")
            }
        }
        
        objectWillChange.send()
    }
    
    func categoryName(for category: String) -> String {
        switch category {
        case "pizza": return "Pizza"
        case "beer": return "Beer"
        case "sushi": return "Sushi"
        case "coffee": return "Coffee"
        case "burger": return "Burger"
        case "mexican": return "Mexican"
        case "ramen": return "Ramen"
        case "salad": return "Salad"
        case "dessert": return "Dessert"
        case "wine": return "Wine"
        case "asian_fusion": return "Asian Fusion"
        case "sandwich": return "Sandwich"
        default: return category.capitalized
        }
    }
    
    func categoryEmoji(for category: String) -> String {
        categories.first(where: { $0.1 == category })?.0 ?? "📍"
    }
    
    func isFavorite(placeId: String) -> Bool {
        return userPreferences.isFavorite(placeId: placeId)
    }
    
    func toggleFavorite(for place: Place) {
        let wasAlreadyFavorite = userPreferences.isFavorite(placeId: place.placeId)
        
        if wasAlreadyFavorite {
            userPreferences.removeFavorite(placeId: place.placeId)
        } else {
            userPreferences.addFavorite(place)
        }
        
        // Debug: Print favorites after change
        print("After toggling favorite for \(place.name):")
        userPreferences.printFavorites()
        
        // Trigger UI update
        objectWillChange.send()
        
        // Provide haptic feedback
        if wasAlreadyFavorite {
            HapticsManager.shared.mediumImpact(intensity: 0.7)
        } else {
            HapticsManager.shared.successSequence()
        }
        
        // Show notification to confirm action
        let actionType = wasAlreadyFavorite ? "removed from" : "added to"
        showNotificationMessage("\(place.name) \(actionType) favorites")
    }
    
    func getRating(for placeId: String) -> Int? {
        // Only return the user's local rating
        return userPreferences.getRating(for: placeId)
    }
    
    func ratePlace(placeId: String, rating: Int) {
        userPreferences.ratePlace(placeId: placeId, rating: rating)
        // Trigger UI update
        objectWillChange.send()
        
        // Show notification to confirm action
        showNotificationMessage("Rating saved")
    }
    
    func onRegionChange(newCenter: CoordinateWrapper) {
        let distanceFromLastQuery = distance(
            from: lastQueriedCenter.coordinate,
            to: newCenter.coordinate
        )
        
        // Only show the search button if we've moved more than 3km from the last query
        if distanceFromLastQuery > 3000 {
            showSearchHereButton = true
        } else {
            showSearchHereButton = false
        }
        
        // We no longer automatically fetch places when the region changes
        // This will be triggered by the "Search Here" button instead
    }
    
    // New function to search at the current location
    func searchHere() {
        // Update the last queried center to the current region center
        lastQueriedCenter = CoordinateWrapper(region.center)
        
        // Hide the search button
        showSearchHereButton = false
        
        // Fetch places at the new location with a 5km radius
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
        }
        
        // Show notification
        showNotificationMessage("Searching in this area")
    }
    
    func onAppear() {
        // Try to use the user's location if available
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
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
                self.shouldCenterOnLocation = false
            }
            
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
            
            // Fetch places at the default location
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    func recenterMap() {
        if let userLocation = locationManager.location {
            // Provide haptic feedback
            HapticsManager.shared.mediumImpact()
            
            print("Recentering map to user location: \(userLocation.coordinate)")
            
            // Update the region to the user's location
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
            
            // Hide the search button since we're at the user's location
            showSearchHereButton = false
            
            // Fetch places at the new location
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
            
            // Show notification
            showNotificationMessage("Centered on your location")
            
            // Explicitly trigger UI update
            objectWillChange.send()
        } else {
            // Provide error feedback if location is not available
            HapticsManager.shared.errorSequence()
            
            // Show notification
            showNotificationMessage("Unable to find your location")
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
        
        // Cancel any previous requests before starting a new one
        (googlePlacesService as? GooglePlacesService)?.cancelPlacesRequests()

        do {
            let activeCategories = selectedCategories.isEmpty ? categories : categories.filter {
                selectedCategories.contains($0.1)
            }
            let fetchedPlaces = try await fetchPlaces(
                center: region.center,
                categories: activeCategories
            )
            
            // Cancel the loading indicator task if it hasn't shown yet
            loadingTask.cancel()
            isLoading = false
            
            self.places = fetchedPlaces
            
            // If we got zero places, provide feedback
            if fetchedPlaces.isEmpty {
                // Provide haptic feedback for no results
                HapticsManager.shared.notification(type: .warning)
                
                // Show notification
                showNotificationMessage("No places found in this area")
            }
        } catch let networkError as NetworkError {
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
                }
            }
            
            print("Network error: \(networkError.localizedDescription)")
        } catch {
            self.error = .unknownError(error)
            self.showError = true
            print("Unknown error: \(error.localizedDescription)")
        }
    }
    
    private func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)]) async throws -> [Place] {
        return try await withCheckedThrowingContinuation { continuation in
            googlePlacesService.fetchPlaces(
                center: center,
                categories: categories,
                showOpenNowOnly: showOpenNowOnly,
                completion: { result in
                    switch result {
                    case .success(let places):
                        continuation.resume(returning: places)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
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
        
        // Hide notification after 5 seconds
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.notificationMessage == message {
                self.showNotification = false
            }
        }
    }
    
    func toggleAllCategories() {
        // Provide haptic feedback
        HapticsManager.shared.prepareGenerators()
        
        // Toggle the All Categories mode
        isAllCategoriesMode.toggle()
        
        if isAllCategoriesMode {
            // If switching to "All" mode, select all categories
            selectedCategories = Set(categories.map { $0.1 })
            HapticsManager.shared.mediumImpact(intensity: 0.8)
            
            // Show appropriate notification based on favorites filter
            if showFavoritesOnly {
                showNotificationMessage("Showing favorites in all categories")
            } else {
                showNotificationMessage("Showing all categories")
            }
        } else {
            // If switching out of "All" mode, clear all categories
            selectedCategories.removeAll()
            HapticsManager.shared.lightImpact(intensity: 0.6)
            
            // Show appropriate notification based on favorites filter
            if showFavoritesOnly {
                showNotificationMessage("Showing all favorites")
            } else {
                showNotificationMessage("No categories selected")
            }
        }
        
        // Since we're using @MainActor, this will be dispatched to the main thread
        Task { [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
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
        (googlePlacesService as? GooglePlacesService)?.cancelPlacesRequests()    
    }
}
