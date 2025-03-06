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
    
    // Filter properties
    @Published var selectedPriceLevels: Set<Int> = [1, 2, 3, 4] // 1-4 representing $ to $$$$
    @Published var showOpenNowOnly: Bool = false
    @Published var minimumRating: Int = 0 // 0-5 stars, 0 means no filter
    @Published var showFilters: Bool = false // Controls filter sheet visibility
    
    private let locationManager = LocationManager()
    private let googlePlacesService: GooglePlacesServiceProtocol
    private let userPreferences: UserPreferences
    private var shouldCenterOnLocation = true
    
    // Computed property to check if all categories are selected
    var areAllCategoriesSelected: Bool {
        selectedCategories.count == categories.count && categories.allSatisfy { selectedCategories.contains($0.1) }
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
            filtered = filtered.filter { place in
                if let rating = place.rating {
                    return rating >= Double(minimumRating)
                }
                return false // Exclude places with no rating if minimum rating is set
            }
        }
        
        return filtered
    }
    
    init(googlePlacesService: GooglePlacesServiceProtocol, userPreferences: UserPreferences = UserPreferences()) {
        self.googlePlacesService = googlePlacesService
        self.userPreferences = userPreferences
        
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
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
        
        setupLocationUpdates()
    }
    
    private func checkConfiguration() {
        if Configuration.isUsingMockKey {
            showConfigWarning = true
            if let errorMessage = Configuration.configurationErrorMessage {
                configWarningMessage = "Configuration Error: \(errorMessage) Using mock data."
            } else {
                configWarningMessage = "Using mock API key. Data shown is not from real API."
            }
        }
    }
    
    private func setupLocationUpdates() {
        // Ensure location updates are handled on the main actor
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            
            // Since we're using @MainActor, this will be dispatched to the main thread
            if self.shouldCenterOnLocation {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.updateRegion(to: location.coordinate)
                    try await self.fetchAndUpdatePlaces()
                    self.shouldCenterOnLocation = false
                }
            }
        }
        
        if let initialLocation = locationManager.location {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updateRegion(to: initialLocation.coordinate)
                try await self.fetchAndUpdatePlaces()
                self.shouldCenterOnLocation = false
            }
        }
    }
    
    func toggleCategory(_ category: String) {
        // Provide haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
        // If "All" is currently selected and we're selecting a specific category
        if isAllCategoriesMode {
            // Turn off "All" mode
            isAllCategoriesMode = false
            // Clear all categories
            selectedCategories.removeAll()
            // Add only the selected category
            selectedCategories.insert(category)
            // Stronger feedback for selection
            feedbackGenerator.impactOccurred(intensity: 0.8)
        } else {
            // Normal toggle behavior when "All" is not selected
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
                // Lighter feedback for deselection
                feedbackGenerator.impactOccurred(intensity: 0.6)
                
                // If we removed a category and now no categories are selected, set isAllCategoriesMode to false
                if selectedCategories.isEmpty {
                    isAllCategoriesMode = false
                }
            } else {
                selectedCategories.insert(category)
                // Stronger feedback for selection
                feedbackGenerator.impactOccurred(intensity: 0.8)
                
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
                let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(separator: ", ")
                showNotificationMessage("Showing favorites in: \(categoryNames)")
            }
        }
        
        // Since we're using @MainActor, this will be dispatched to the main thread
        Task {
            try await self.fetchAndUpdatePlaces()
        }
    }
    
    func toggleFavoritesFilter() {
        // Provide haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
        showFavoritesOnly.toggle()
        
        // Provide appropriate feedback based on state
        if showFavoritesOnly {
            // Stronger feedback when enabling favorites
            feedbackGenerator.impactOccurred(intensity: 0.9)
        } else {
            // Lighter feedback when disabling
            feedbackGenerator.impactOccurred(intensity: 0.7)
        }
        
        // Show notification with haptic feedback
        if showFavoritesOnly {
            if selectedCategories.isEmpty {
                showNotificationMessage("Showing all favorites")
            } else {
                let categoryNames = selectedCategories.map { categoryName(for: $0) }.joined(separator: ", ")
                showNotificationMessage("Showing favorites in: \(categoryNames)")
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
        if userPreferences.isFavorite(placeId: place.placeId) {
            userPreferences.removeFavorite(placeId: place.placeId)
        } else {
            userPreferences.addFavorite(place)
        }
        // Trigger UI update
        objectWillChange.send()
    }
    
    func getRating(for placeId: String) -> Int? {
        return userPreferences.getRating(for: placeId)
    }
    
    func ratePlace(placeId: String, rating: Int) {
        userPreferences.ratePlace(placeId: placeId, rating: rating)
        // Trigger UI update
        objectWillChange.send()
    }
    
    func onRegionChange(newCenter: CoordinateWrapper) {
        let distanceFromLastQuery = distance(from: lastQueriedCenter.coordinate, to: newCenter.coordinate)
        
        // Only show the search button if we've moved more than 5km from the last query
        // This matches the radius used in the API request
        if distanceFromLastQuery > 5000 {
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
        
        // Fetch places at the new location
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
        }
        
        // Show notification
        showNotificationMessage("Searching in this area")
    }
    
    func onAppear() {
        if let userLocation = locationManager.location {
            updateRegion(to: userLocation.coordinate)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
                self.shouldCenterOnLocation = false
            }
        } else {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    func recenterMap() {
        if let userLocation = locationManager.location {
            updateRegion(to: userLocation.coordinate)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
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
        isLoading = true
        error = nil
        showError = false
        
        // Cancel any previous requests before starting a new one
        (googlePlacesService as? GooglePlacesService)?.cancelPlacesRequests()
        
        do {
            let activeCategories = selectedCategories.isEmpty ? categories : categories.filter { selectedCategories.contains($0.1) }
            let fetchedPlaces = try await fetchPlaces(center: region.center, categories: activeCategories)
            self.places = fetchedPlaces
        } catch let networkError as NetworkError {
            self.error = networkError
            // Only show error alert if it's not a cancelled request
            self.showError = networkError.shouldShowAlert
            print("Network error: \(networkError.localizedDescription)")
        } catch {
            self.error = .unknownError(error)
            self.showError = true
            print("Unknown error: \(error.localizedDescription)")
        }
        
        isLoading = false
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
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        lastQueriedCenter = CoordinateWrapper(coordinate)
    }
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }
    
    func showNotificationMessage(_ message: String) {
        notificationMessage = message
        showNotification = true
        
        // Hide notification after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if notificationMessage == message {
                showNotification = false
            }
        }
    }
    
    func toggleAllCategories() {
        // Provide haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
        // Toggle the All Categories mode
        isAllCategoriesMode.toggle()
        
        if isAllCategoriesMode {
            // If switching to "All" mode, select all categories
            selectedCategories = Set(categories.map { $0.1 })
            feedbackGenerator.impactOccurred(intensity: 0.8)
            
            // Show appropriate notification based on favorites filter
            if showFavoritesOnly {
                showNotificationMessage("Showing favorites in all categories")
            } else {
                showNotificationMessage("Showing all categories")
            }
        } else {
            // If switching out of "All" mode, clear all categories
            selectedCategories.removeAll()
            feedbackGenerator.impactOccurred(intensity: 0.6)
            
            // Show appropriate notification based on favorites filter
            if showFavoritesOnly {
                showNotificationMessage("Showing all favorites")
            } else {
                showNotificationMessage("No categories selected")
            }
        }
        
        // Since we're using @MainActor, this will be dispatched to the main thread
        Task {
            try await self.fetchAndUpdatePlaces()
        }
    }
    
    // Function to recommend a random place based on current filters
    func recommendRandomPlace() {
        // Get the filtered places based on current selection
        let availablePlaces = filteredPlaces
        
        // Check if there are any places to recommend
        if availablePlaces.isEmpty {
            showNotificationMessage("No places to recommend with current filters")
            return
        }
        
        // Select a random place from the filtered list
        if let randomPlace = availablePlaces.randomElement() {
            // Provide haptic feedback
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred(intensity: 1.0)
            
            // Update the selected place to show its details
            selectedPlace = randomPlace
            
            // Show a notification
            let categoryName = categoryName(for: randomPlace.category)
            showNotificationMessage("Recommended: \(randomPlace.name) (\(categoryName))")
            
            // Update the map region to center on this place
            updateRegion(to: randomPlace.coordinate)
        }
    }
    
    // Cancel all pending requests when the view model is deallocated
    deinit {
        (googlePlacesService as? GooglePlacesService)?.cancelAllRequests()
    }
}
