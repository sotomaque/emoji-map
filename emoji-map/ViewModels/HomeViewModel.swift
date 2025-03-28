//
//  HomeViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import Swift
import CoreLocation
import MapKit
import Combine
import os.log
import Clerk
import CryptoKit

/// Protocol abstracting the Clerk functionality we need for testing
protocol ClerkService {
    var isLoaded: Bool { get }
    var user: User? { get }
    var userId: String? { get }
    var isAdmin: Bool { get }
    
    func getSessionToken() async throws -> String?
    func getSessionId() async throws -> String?
}

/// Default implementation that uses the real Clerk.shared
class DefaultClerkService: ClerkService {
    @MainActor
    var isLoaded: Bool {
        return Clerk.shared.isLoaded
    }
    
    @MainActor
    var user: User? {
        return Clerk.shared.user
    }
    
    @MainActor
    var userId: String? {
        return Clerk.shared.user?.id
    }
    
    @MainActor
    var isAdmin: Bool {
        // Check if the user exists and has admin: true in publicMetadata
        return Clerk.shared.user?.publicMetadata?["admin"]?.boolValue ?? false
    }
    
    @MainActor
    func getSessionToken() async throws -> String? {
        guard let session = Clerk.shared.session else {
            print("No active session")
            return nil
        }
        let tokenResource = try await session.getToken()
        return tokenResource?.jwt
    }
    
    @MainActor
    func getSessionId() async throws -> String? {
        guard let session = Clerk.shared.session else {
            print("No active session")
            return nil
        }
        // Return the session ID
        return session.id
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    // Published properties for UI state
    @Published private var allPlacesById: [String: Place] = [:]  // All places loaded from API
    @Published private var networkFilteredPlaceIds: Set<String> = [] // IDs of places from network-dependent filters
    @Published private(set) var filteredPlaces: [Place] = [] // View-facing filtered list
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterSheetPresented = false
    @Published var isSettingsSheetPresented = false
    @Published var selectedPlace: Place?
    @Published var isPlaceDetailSheetPresented = false
    
    // User data
    @Published var currentUser: AppUser?
    @Published var isLoadingUser = false
    @Published var isAdmin: Bool = false
    
    // Category selection state
    @Published var selectedCategoryKeys: Set<Int> = []
    @Published var isAllCategoriesMode: Bool = true
    @Published var showFavoritesOnly: Bool = false
    @Published var isCategoryGridViewVisible: Bool = false // Track grid view visibility
    
    // Temporary category selections for grid view
    @Published var pendingCategoryKeys: Set<Int> = []
    @Published var isPendingAllCategoriesMode: Bool = true
    
    // Filter state
    @Published var selectedPriceLevels: Set<Int> = []
    @Published var minimumRating: Int = 0
    @Published var useLocalRatings: Bool = false
    @Published var showOpenNowOnly: Bool = false
    
    // For category mapping - replace allPlacesByCategory
    private var categoryPlaceIds: [Int: Set<String>] = [:]
    
    // Flag to track if a network request for selected categories is in progress
    private var isFetchingCategories = false
    
    // Map state
    @Published var visibleRegion: MKCoordinateRegion?
    private var lastFetchedRegion: MKCoordinateRegion?
    private var regionChangeDebounceTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var isSuperZoomedIn: Bool = false // Track super zoomed in state
    private var currentViewportRadius: Double = 5000 // Default radius in meters

    // Location manager
    let locationManager = LocationManager()
    
    // Services
    let placesService: PlacesServiceProtocol
    let userPreferences: UserPreferences
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "HomeViewModel")
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property to check if all price levels are selected or none are selected
    var allPriceLevelsSelected: Bool {
        // If no price levels are selected, it means we're not filtering by price level
        if self.selectedPriceLevels.isEmpty {
            return true
        }
        
        // If all price levels (1-4) are selected, it's equivalent to no price level filter
        let allSelected = self.selectedPriceLevels.count == 4 &&
            self.selectedPriceLevels.contains(1) &&
            self.selectedPriceLevels.contains(2) &&
            self.selectedPriceLevels.contains(3) &&
            self.selectedPriceLevels.contains(4)
        
        return allSelected
    }
    
    var hasPriceLevelFilters: Bool {
        // Define the full range of possible price levels (1 to 4)
        let allPriceLevels: Set<Int> = [1, 2, 3, 4]
        
        // Check if selectedPriceLevels is not empty and not equal to all possible levels
        return !selectedPriceLevels.isEmpty && selectedPriceLevels != allPriceLevels
    }
    
    var hasOpenNowFilter: Bool {
        return self.showOpenNowOnly
    }
    
    // Rating set and source set to Google, not Local User Ratings
    var hasGoogleRatingFilter: Bool {
        return self.minimumRating > 0 && !self.useLocalRatings
    }
    
    // TRUE if we have any of the following
    // Open Now On
    // Price Level -> non-default
    // Google Minimum Ratings
    var hasNetworkDependentFilters: Bool {
        // Return true if any network-dependent filter is active
        return self.hasPriceLevelFilters || self.hasOpenNowFilter || self.hasGoogleRatingFilter
    }
    
    var hasNonNetworkDependentFilters: Bool {
        return showFavoritesOnly || // Favorites filter is client-side
               (minimumRating > 0 && useLocalRatings) || // Local ratings filter is client-side
               (!isAllCategoriesMode && !selectedCategoryKeys.isEmpty) // Category filter can be client-side if data is local
    }
    
    // Computed property to check if there are active filters
    var hasActiveFilters: Bool {
        // Price level filter is active if not all price levels are selected
        // (allPriceLevelsSelected handles both empty and all-selected cases)
        let hasPriceLevelFilters = !allPriceLevelsSelected
        
        // Check if minimum rating filter is active
        let hasRatingFilter = minimumRating > 0
        
        // Check if open now filter is active
        let hasOpenNowFilter = showOpenNowOnly
        
        // Return true if any filter is active
        return hasPriceLevelFilters || hasRatingFilter || hasOpenNowFilter
    }
    
    
    // Helper property to get all places as an array (for cases where we need the array form)
    private var allPlaces: [Place] {
        Array(allPlacesById.values)
    }
    
    // MARK: - Properties for backward compatibility
    
    /// Public accessor for all places (for backward compatibility)
    var places: [Place] {
        Array(allPlacesById.values)
    }
    
    /// Method to set places directly (for testing and preview purposes)
    func setPlaces(_ newPlaces: [Place]) {
        // Clear existing places
        allPlacesById.removeAll()
        
        // Add the new places
        for place in newPlaces {
            allPlacesById[place.id] = place
        }
        
        // Update filtered places
        updateFilteredPlaces()
    }
    
    // MARK: - Initialization
    
    init(placesService: PlacesServiceProtocol, 
         userPreferences: UserPreferences, 
         networkService: NetworkServiceProtocol? = nil,
         clerkService: ClerkService = DefaultClerkService()) {
        self.placesService = placesService
        self.userPreferences = userPreferences
        logger.notice("HomeViewModel initialized")
        
        // Set the initial admin status
        self.isAdmin = clerkService.isAdmin
        logger.notice("Initial admin status: \(self.isAdmin)")
        
        setupLocationManager()
        
        // Subscribe to changes in userPreferences.placeRatings
        userPreferences.$placeRatings
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // If we're using local ratings for filtering, update filtered places when ratings change
                if self.useLocalRatings && self.minimumRating > 0 {
                    self.logger.notice("User ratings changed - updating filtered places to reflect new ratings")
                    Task { @MainActor in
                        self.updateFilteredPlaces()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Fetch user data in the background
        Task {
            await fetchUserData(networkService: networkService, clerkService: clerkService)
        }
    }
    
    deinit {
        // Cancel any pending tasks
        regionChangeDebounceTask?.cancel()
        fetchTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Reset user data and admin state when logging out
    func resetUserState() {
        currentUser = nil
        isAdmin = false
        isLoadingUser = false
    }
    
    /// Reset all view model state to initial values
    func resetAllState() {
        // Reset user state
        resetUserState()
        
        // Reset UI state
        allPlacesById.removeAll()
        networkFilteredPlaceIds.removeAll()
        filteredPlaces.removeAll()
        isLoading = false
        errorMessage = nil
        isFilterSheetPresented = false
        isSettingsSheetPresented = false
        selectedPlace = nil
        isPlaceDetailSheetPresented = false
        
        // Reset category selection state
        selectedCategoryKeys.removeAll()
        isAllCategoriesMode = true
        showFavoritesOnly = false
        isCategoryGridViewVisible = false
        
        // Reset pending category selections
        pendingCategoryKeys.removeAll()
        isPendingAllCategoriesMode = true
        
        // Reset filter state
        selectedPriceLevels.removeAll()
        minimumRating = 0
        useLocalRatings = false
        showOpenNowOnly = false
        
        // Reset category mapping
        categoryPlaceIds.removeAll()
        
        // Reset map state
        visibleRegion = nil
        lastFetchedRegion = nil
        isSuperZoomedIn = false
        currentViewportRadius = 5000 // Default radius
        
        // Cancel any pending tasks
        regionChangeDebounceTask?.cancel()
        fetchTask?.cancel()
    }
    
    /// Fetch user data from the API
    func fetchUserData(networkService: NetworkServiceProtocol? = nil, clerkService: ClerkService? = nil) async {
        logger.notice("Checking for authenticated user")
        
        // Get Clerk instance or use the provided one
        let clerk = clerkService ?? DefaultClerkService()
        
        // Make sure Clerk is fully loaded
        if !clerk.isLoaded {
            logger.notice("Clerk is not fully loaded yet. Skipping user data request.")
            return
        }
        
        // Update admin status
        isAdmin = clerk.isAdmin
        logger.notice("Updated admin status: \(self.isAdmin)")
        
        // Check if user is authenticated
        if let userId = clerk.userId {
            logger.notice("User is authenticated with Clerk. User ID: \(userId)")
            
            // Set loading state
            isLoadingUser = true
            
            do {
                // Get the network service from the service container or use the provided one
                let networkService = networkService ?? ServiceContainer.shared.networkService
                
                // Get the session token for authentication
                guard let sessionToken = try await clerk.getSessionToken() else {
                    logger.error("No session token available for authentication")
                    isLoadingUser = false
                    return
                }
                
                // Get local favorites and ratings
                let localFavorites = userPreferences.favoritePlaceIds.map { FavoriteSync(placeId: $0) }
                let localRatings = userPreferences.placeRatings.map { RatingSync(placeId: $0.key, rating: $0.value) }
                
                // Create request body
                let requestBody = UserSyncRequest(
                    favorites: localFavorites,
                    ratings: localRatings
                )
                
                logger.notice("Making authenticated request to /api/user/sync with Bearer token")
                logger.notice("Local favorites count: \(localFavorites.count)")
                logger.notice("Local ratings count: \(localRatings.count)")
                
                // Make the request to the user sync endpoint with token-based authentication
                let userResponse: UserResponse = try await networkService.post(
                    endpoint: .userSync,
                    body: requestBody,
                    queryItems: nil,
                    authToken: sessionToken
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
                
                // Log ratings information
                logger.notice("  Ratings: \(user.ratings.count)")
                for (index, rating) in user.ratings.enumerated() {
                    logger.notice("    Rating \(index + 1): Place ID: \(rating.placeId), Rating: \(rating.rating)")
                }
                
                // Store the user data
                currentUser = user
                
                // Save user ID and email to UserPreferences
                userPreferences.saveUserData(id: user.id, email: user.email)
                
                // Synchronize favorites with API data
                userPreferences.syncFavoritesWithAPI(apiFavorites: user.favorites)
                
                // Synchronize ratings with API data
                userPreferences.syncRatingsWithAPI(apiRatings: user.ratings)
                
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
    
    /// Handle sign-in with Apple credentials
    /// This method moves the sign-in logic from the SettingsSheet to the ViewModel
    func signInWithApple(idToken: String) async throws {
        logger.notice("Attempting to authenticate with Clerk using Apple ID token")
        do {
            // Use the standard authenticateWithIdToken method
            try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
            logger.notice("User signed in with Apple successfully")
            
            // Fetch user data which will sync favorites with API
            await fetchUserData()
            
            return
        } catch let clerkError {
            logger.error("Clerk authentication error: \(clerkError.localizedDescription)")
            throw clerkError
        }
    }
    
    /// Generate a secure random nonce for Apple Sign In
    /// This method is moved from SettingsSheet to make it reusable and keep auth logic in ViewModel
    func generateRandomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    logger.error("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                    fatalError("Unable to generate random nonce: \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// Hash a string using SHA256
    /// This method is moved from SettingsSheet to make it reusable and keep auth logic in ViewModel
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
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
        
        // Define a threshold for "super zoomed in" state
        // Lower values mean more zoomed in (smaller visible area)
        let superZoomedInThreshold: Double = 0.005 // This value can be adjusted later
        
        // Check if we're super zoomed in based on the span
        let averageSpan = (region.span.latitudeDelta + region.span.longitudeDelta) / 2
        isSuperZoomedIn = averageSpan < superZoomedInThreshold
        
        // Calculate an appropriate radius based on the visible region
        // Convert latitude/longitude span to approximate meters
        // 1 degree of latitude ≈ 111km, so we use the average span × 111000 / 2
        let spanInMeters = (region.span.latitudeDelta + region.span.longitudeDelta) * 111000 / 2
        
        // Set the current viewport radius to be appropriate for the map view
        // Use 75% of the span to ensure we get places within the visible area with some margin
        currentViewportRadius = spanInMeters * 0.75
        
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
                let center = region.center
                
                // Determine which API endpoint to use based on category selection
                if !isAllCategoriesMode && !selectedCategoryKeys.isEmpty {
                    // If specific categories are selected, use the category-specific endpoint
                    fetchPlacesByCategories(at: center)
                } else {
                    // Otherwise use the regular nearby places endpoint
                    fetchNearbyPlaces(at: center)
                    
                    // If we have network-dependent filters, also fetch filtered places
                    if hasNetworkDependentFilters {
                        // Fetch filtered places with the same location
                        await fetchPlacesWithFilters(at: center)
                    }
                }
            }
        }
    }
    
    /// Refresh places based on current location
    /// - Parameter clearExisting: Whether to clear existing places before refreshing (default: false)
    func refreshPlaces(clearExisting: Bool = false) {
        // Clear existing places if requested
        if clearExisting {
            allPlacesById.removeAll()
        }
        
        // Determine which location to use
        let location = visibleRegion?.center ?? locationManager.lastLocation?.coordinate
        
        guard let location = location else {
            errorMessage = "Unable to determine your location"
            logger.error("Refresh failed: No location available")
            return
        }
        
        // Determine which API endpoint to use based on category selection
        if !isAllCategoriesMode && !selectedCategoryKeys.isEmpty {
            // If specific categories are selected, use the category-specific endpoint
            fetchPlacesByCategories(at: location)
        } else {
            // Otherwise use the regular nearby places endpoint
            fetchNearbyPlaces(at: location, useCache: false)
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
        
        // Update filtered places based on the current state
        updateFilteredPlaces()
    }
    
    /// Toggle all categories mode
    func toggleAllCategories() {
        // If already in "All" mode, do nothing (prevent deselection)
        if isAllCategoriesMode {
            return
        }
        
        // Otherwise, enable "All" mode
        isAllCategoriesMode = true
        
        // Clear selected categories when "All" is selected
        selectedCategoryKeys.removeAll()
        
        applyFilters()
    }
    
    /// Toggle a specific category
    func toggleCategory(key: Int, emoji: String) {
        if selectedCategoryKeys.contains(key) {
            selectedCategoryKeys.remove(key)
        } else {
            selectedCategoryKeys.insert(key)
        }
        
        // If no categories are selected, switch to "All" mode
        if selectedCategoryKeys.isEmpty {
            isAllCategoriesMode = true
            
            // When switching back to "All" mode, restore full places list
            if !hasNetworkDependentFilters {
                // Use the full places list for filtering immediately
                updateFilteredPlaces()
            } else {
                // For network-dependent filters, keep using those
                updateFilteredPlaces()
            }
        } else {
            // If we're switching from "All" to specific categories
            let wasAllMode = isAllCategoriesMode
            isAllCategoriesMode = false
            
            // If this is the first category selection (switching from All mode),
            // we'll need to refresh the filtered list completely
            if wasAllMode {
                // Clear network filtered places when switching modes to ensure we get fresh data
                if hasNetworkDependentFilters {
                    resetNetworkFilteredPlaces()
                }
            }
        }
        
        // Immediately update filtered places with what we have locally
        updateFilteredPlaces()
        
        // If in a specific category mode and not already fetching, fetch more places
        if !isAllCategoriesMode && !isFetchingCategories {
            fetchPlacesByCategories()
        }
    }
    
    /// Apply filters to places based on selected categories and other filters
    func applyFilters() {
        // Create the request body with the selected filters
        let location = visibleRegion?.center ?? locationManager.lastLocation?.coordinate
        
        guard let location = location else {
            errorMessage = "Unable to determine your location"
            logger.error("Apply filters failed: No location available")
            return
        }
        
        // Clear network filtered places when filter criteria change
        if hasNetworkDependentFilters {
            resetNetworkFilteredPlaces()
        }
        
        // First update filtered places with what we have locally
        updateFilteredPlaces()
        
        // Then fetch more places with the new filters in the background
        Task {
            await fetchPlacesWithFilters(at: location)
        }
    }
    
    /// Fetch places with applied filters
    private func fetchPlacesWithFilters(at location: CLLocationCoordinate2D) async {
        guard !self.isLoading else {
            return
        }
        
        if !self.hasNetworkDependentFilters {
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // If all price levels are selected or none are selected, treat it as if no price level filter is applied
            let priceLevelsToUse: [Int]?
            if self.selectedPriceLevels.isEmpty || self.allPriceLevelsSelected {
                priceLevelsToUse = nil
            } else {
                let sortedLevels = Array(self.selectedPriceLevels).sorted()
                priceLevelsToUse = sortedLevels
            }
            
            // Determine if we should include minimum rating in the request
            // Only include it when using Google Maps ratings (not local ratings)
            let minimumRatingToUse: Int?
            if !self.useLocalRatings && self.minimumRating > 0 {
                minimumRatingToUse = self.minimumRating
            } else {
                minimumRatingToUse = nil
            }
            
            // Get the current search radius
            let searchRadius = getSearchRadius()
            
            // Create request body with filters
            let requestBody = PlaceSearchRequest(
                keys: self.isAllCategoriesMode ? nil : Array(self.selectedCategoryKeys),
                openNow: self.showOpenNowOnly,
                priceLevels: priceLevelsToUse,
                radius: searchRadius,
                location: PlaceSearchRequest.LocationCoordinate(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                bypassCache: true,
                maxResultCount: nil,
                minimumRating: minimumRatingToUse
            )
                        
            let response: PlacesResponse = try await placesService.fetchWithFilters(
                location: location,
                requestBody: requestBody
            )
            
            // Always merge into main places collection to maintain a complete set
            mergePlaces(response.results)
            
            // Also merge into network filtered places
            mergeNetworkFilteredPlaces(response.results)
            
            // Update the filtered places to include both local and network filtered results
            updateFilteredPlaces()
            
            // Ensure loading indicator is turned off
            self.isLoading = false
        } catch {
            logger.error("Failed to fetch places with filters: \(error.localizedDescription)")
            self.errorMessage = "Failed to fetch places: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    /// Fetch places by selected category keys
    private func fetchPlacesByCategories(at location: CLLocationCoordinate2D? = nil) {
        // Only proceed if we have categories selected
        guard !selectedCategoryKeys.isEmpty else {
            return
        }
        
        // Mark that we're fetching to prevent duplicate requests
        isFetchingCategories = true
        
        // Cancel any existing fetch task
        fetchTask?.cancel()
        
        // Determine the location to use
        let fetchLocation = location ?? visibleRegion?.center ?? locationManager.lastLocation?.coordinate
        
        // Only proceed if we have a location
        guard let fetchLocation = fetchLocation else {
            isFetchingCategories = false
            return
        }
        
        // Get the current search radius
        let searchRadius = getSearchRadius()
                
        // Create a new fetch task
        fetchTask = Task {
            do {
                let categoryKeysArray = Array(selectedCategoryKeys) 
                let fetchedPlaces = try await placesService.fetchPlacesByCategories(
                    location: fetchLocation,
                    categoryKeys: categoryKeysArray,
                    bypassCache: isSuperZoomedIn, // Add bypassCache parameter
                    radius: searchRadius // Pass the current search radius
                )
                
                // Check if the task was cancelled
                if Task.isCancelled { 
                    isFetchingCategories = false
                    return 
                }
                
                // Merge new places into the all places collection
                mergePlaces(fetchedPlaces)
                
                // Also track places by category to maintain a complete collection
                for categoryKey in selectedCategoryKeys {
                    if categoryPlaceIds[categoryKey] == nil {
                        categoryPlaceIds[categoryKey] = []
                    }
                    
                    // Add the fetched places to this category collection
                    mergePlacesIntoCategory(fetchedPlaces, categoryKey: categoryKey)
                }
                                
                // If we have network-dependent filters, fetch filtered places
                if hasNetworkDependentFilters {
                    // Fetch filtered places with the same location
                    await fetchPlacesWithFilters(at: fetchLocation)
                } else {
                    // Otherwise just apply local filtering
                    updateFilteredPlaces()
                }
                
                isFetchingCategories = false
            } catch {
                // Check if the task was cancelled
                if Task.isCancelled { 
                    isFetchingCategories = false
                    return 
                }
                
                self.errorMessage = "Failed to load places by categories: \(error.localizedDescription)"
                logger.error("Error fetching places by categories: \(error.localizedDescription)")
                isFetchingCategories = false
            }
        }
    }
    
    /// Merge places into a specific category collection
    private func mergePlacesIntoCategory(_ newPlaces: [Place], categoryKey: Int) {
        guard let emoji = CategoryMappings.getEmojiForKey(categoryKey) else {
            return
        }
                
        // Initialize the set if it doesn't exist
        if categoryPlaceIds[categoryKey] == nil {
            categoryPlaceIds[categoryKey] = []
        }
        
        var categoryPlaceIdsSet = categoryPlaceIds[categoryKey] ?? []
        let countBefore = categoryPlaceIdsSet.count
                
        // Filter to places that contain this emoji category
        let placesWithEmoji = newPlaces.filter { place in
            let contains = place.emoji.contains(emoji)
            return contains
        }
        
        // Add place IDs to the category
        for place in placesWithEmoji {
            categoryPlaceIdsSet.insert(place.id)
            
            // Also ensure the place is in the main collection
            allPlacesById[place.id] = place
        }
        
        categoryPlaceIds[categoryKey] = categoryPlaceIdsSet
    }
    
    /// Merge new places into the network filtered collection
    private func mergeNetworkFilteredPlaces(_ newPlaces: [Place]) {
        // Count before adding
        let countBefore = networkFilteredPlaceIds.count
        
        // Add the IDs of the new places
        for place in newPlaces {
            networkFilteredPlaceIds.insert(place.id)
            
            // Also ensure the place is in the main collection
            allPlacesById[place.id] = place
        }
    }
    
    /// Update the filtered places based on current filter settings
    public func updateFilteredPlaces() {
        // Start with the appropriate source collection
        var filteredIds: Set<String>
        
        if hasNetworkDependentFilters {
            // Start with network filtered places if we have network-dependent filters
            filteredIds = networkFilteredPlaceIds
        } else {
            // Otherwise, start with all places
            filteredIds = Set(allPlacesById.keys)
        }
        
        // Apply favorites filter if enabled
        if showFavoritesOnly {
            let beforeFavCount = filteredIds.count
            filteredIds = filteredIds.filter { userPreferences.isFavorite(placeId: $0) }
        }
        
        // Apply category filter if not in all categories mode
        if !isAllCategoriesMode && !selectedCategoryKeys.isEmpty {
            // Create a set of all places that match any of the selected categories
            let categoryMatchingIds = selectedCategoryKeys.reduce(into: Set<String>()) { result, key in
                if let categoryIds = categoryPlaceIds[key] {
                    result.formUnion(categoryIds)
                }
            }
            
            let beforeCatCount = filteredIds.count
            
            // If we have precomputed category matches, use them
            if !categoryMatchingIds.isEmpty {
                filteredIds = filteredIds.intersection(categoryMatchingIds)
            } else {
                // This is less efficient, but necessary as a fallback
                filteredIds = filteredIds.filter { placeId in
                    guard let place = allPlacesById[placeId] else { return false }
                    
                    let containsCategory = CategoryMappings.placeContainsSelectedCategories(
                        placeEmoji: place.emoji, 
                        selectedCategoryKeys: selectedCategoryKeys
                    )
                    
                    return containsCategory
                }
            }
        }
        
        // Apply rating filter if set
        if minimumRating > 0 {
            if useLocalRatings {
                // Use local user ratings
                filteredIds = filteredIds.filter { placeId in
                    let userRating = userPreferences.getRating(placeId: placeId)
                    return Double(userRating) >= Double(self.minimumRating)
                }
                logger.notice("Filtered to \(filteredIds.count) place IDs with local rating >= \(self.minimumRating)")
            } else if !hasNetworkDependentFilters {
                // Use Google ratings only for local filtering (if network filtering isn't in use)
                filteredIds = filteredIds.filter { placeId in
                    guard let place = allPlacesById[placeId], let rating = place.rating else {
                        return false
                    }
                    return rating >= Double(self.minimumRating)
                }
                logger.notice("Filtered to \(filteredIds.count) place IDs with Google rating >= \(self.minimumRating)")
            }
        }
        
        // Apply price level filter if any are selected and not using network filters
        if !self.allPriceLevelsSelected && !self.hasNetworkDependentFilters {
            filteredIds = filteredIds.filter { [self] placeId in
                guard let place = allPlacesById[placeId] else { return false }
                
                if let priceLevel = place.priceLevel {
                    return self.selectedPriceLevels.contains(priceLevel)
                }
                // If no price level is specified, include it if price level 1 is selected
                return self.selectedPriceLevels.contains(1)
            }
            logger.notice("Filtered to \(filteredIds.count) place IDs with selected price levels")
        }
        
        // Convert filtered IDs back to Place objects
        let newFilteredPlaces = filteredIds.compactMap { allPlacesById[$0] }
        
        // Set the filtered places
        filteredPlaces = newFilteredPlaces
        
        // Log final count
        logger.notice("Final filteredPlaces count: \(self.filteredPlaces.count)")
    }
    
    /// Set all price levels (1-4) as selected
    func selectAllPriceLevels() {
        self.selectedPriceLevels = [1, 2, 3, 4]
        logger.notice("All price levels selected: \(self.selectedPriceLevels.sorted())")
        updateFilteredPlaces()
    }
    
    /// Clear all price levels and select only the specified level
    func selectOnlyPriceLevel(_ level: Int) {
        guard (1...4).contains(level) else {
            logger.error("Invalid price level: \(level)")
            return
        }
        
        // Clear all selections and select only the specified level
        self.selectedPriceLevels.removeAll()
        self.selectedPriceLevels.insert(level)
        logger.notice("Selected only price level \(level)")
        
        // Update filtered places to reflect the new selection
        updateFilteredPlaces()
    }
    
    /// Recommend a random place from the filtered places list
    @MainActor
    public func recommendRandomPlace() {
        if filteredPlaces.isEmpty {
            logger.notice("Cannot recommend a place: No filtered places available")
            return
        }
        
        // Select a random place from the filtered places
        if let randomPlace = filteredPlaces.randomElement() {
            logger.notice("Recommending random place: \(randomPlace.displayName ?? "Unknown")")
            selectedPlace = randomPlace
            isPlaceDetailSheetPresented = true
        } else {
            logger.error("Failed to select a random place even though filtered places is not empty")
        }
    }
    
    /// Updates the filtered places after a rating change (mainly used for testing)
    @MainActor
    public func updateFilteredPlacesAfterRatingChange() {
        if useLocalRatings && minimumRating > 0 {
            logger.notice("Manually updating filtered places after rating change")
            updateFilteredPlaces()
        }
    }
    
    // MARK: - Private Methods
    /// Get the appropriate search radius based on the current viewport
    private func getSearchRadius() -> Int {
        // Round to nearest 100 meters for cleaner values
        let radius = Int(currentViewportRadius.rounded() / 100) * 100
        
        // Use Configuration values instead of hardcoded ones
        let minRadius = Configuration.minSearchRadius
        let maxRadius = Configuration.maxSearchRadius
        
        // Return the clamped value
        return min(max(radius, minRadius), maxRadius)
    }
    
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
        let shouldShowLoading = allPlaces.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        
        errorMessage = nil
        
        // Store the current region as the last fetched region
        lastFetchedRegion = visibleRegion
        
        // Get the search radius based on the current viewport
        let searchRadius = getSearchRadius()
        
        // Log if we're bypassing cache due to being super zoomed in
        if isSuperZoomedIn {
            logger.notice("Super zoomed in mode - adding bypassCache parameter to request")
        }
        
        logger.notice("Fetching nearby places at \(coordinate.latitude), \(coordinate.longitude), radius: \(searchRadius)m")
        
        // Create a new fetch task
        fetchTask = Task {
            do {
                let fetchedPlaces = try await placesService.fetchNearbyPlaces(
                    location: coordinate,
                    useCache: useCache && !isSuperZoomedIn, // Don't use cache if super zoomed in
                    radius: searchRadius
                )
                
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                // Merge new places with existing places instead of replacing
                mergePlaces(fetchedPlaces)
                logger.notice("Fetched \(fetchedPlaces.count) places, total places now: \(self.allPlaces.count)")
                
                // If we have network-dependent filters, fetch filtered places
                if hasNetworkDependentFilters {
                    // Fetch filtered places with the same location
                    await fetchPlacesWithFilters(at: coordinate)
                } else {
                    // Otherwise just apply local filtering
                    updateFilteredPlaces()
                }
                
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
    
    /// Merge new places with existing places, avoiding duplicates
    private func mergePlaces(_ newPlaces: [Place]) {
        // Count before adding
        let countBefore = allPlacesById.count
        
        // Add or update places
        for place in newPlaces {
            allPlacesById[place.id] = place
        }
        
        // Log how many new places were added
        let addedCount = allPlacesById.count - countBefore
        if addedCount > 0 {
            logger.notice("Added \(addedCount) new unique places, total now: \(self.allPlacesById.count)")
        } else {
            logger.notice("No new unique places to add, total remains: \(self.allPlacesById.count)")
        }
    }
    
    /// Clear all places (useful for reset functionality if needed)
    func clearPlaces() {
        allPlacesById.removeAll()
        networkFilteredPlaceIds.removeAll()
        categoryPlaceIds.removeAll()
        filteredPlaces.removeAll()
        logger.notice("Cleared all places")
    }
    
    // New helper method to reset network filtered places
    private func resetNetworkFilteredPlaces() {
        networkFilteredPlaceIds.removeAll()
        logger.notice("Reset network filtered place IDs")
    }
    
    // Initialize grid view with current category selections
    func initializePendingCategories() {
        pendingCategoryKeys = selectedCategoryKeys
        isPendingAllCategoriesMode = isAllCategoriesMode
    }
    
    // Toggle a category in pending selections (for grid view)
    func togglePendingCategory(key: Int) {
        if pendingCategoryKeys.contains(key) {
            pendingCategoryKeys.remove(key)
        } else {
            pendingCategoryKeys.insert(key)
        }
        
        // If no categories are selected, switch to "All" mode
        if pendingCategoryKeys.isEmpty {
            isPendingAllCategoriesMode = true
        } else {
            isPendingAllCategoriesMode = false
        }
    }
    
    // Toggle all categories mode in pending selections
    func togglePendingAllCategories() {
        isPendingAllCategoriesMode.toggle()
        // If switching to "All" mode, clear the selected categories
        if isPendingAllCategoriesMode {
            pendingCategoryKeys.removeAll()
        }
    }
    
    // Apply pending category selections to actual selections
    func applyPendingCategories() {
        selectedCategoryKeys = pendingCategoryKeys
        isAllCategoriesMode = isPendingAllCategoriesMode
        
        // Update filters based on new selections
        if isAllCategoriesMode {
            if !hasNetworkDependentFilters {
                updateFilteredPlaces()
            } else {
                updateFilteredPlaces()
            }
        } else {
            if hasNetworkDependentFilters {
                resetNetworkFilteredPlaces()
            }
            fetchPlacesByCategories()
        }
    }
    
    /// Update user information
    /// - Parameters:
    ///   - email: User's email
    ///   - firstName: User's first name (optional)
    ///   - lastName: User's last name (optional)
    ///   - networkService: Optional network service for testing
    ///   - clerkService: Optional clerk service for testing
    func updateUserInfo(
        email: String,
        firstName: String = "",
        lastName: String = "",
        networkService: NetworkServiceProtocol? = nil,
        clerkService: ClerkService? = nil
    ) async throws {
        logger.notice("Updating user information")
        
        // Get Clerk instance or use the provided one
        let clerk = clerkService ?? DefaultClerkService()
        
        // Get the network service from the service container or use the provided one
        let networkService = networkService ?? ServiceContainer.shared.networkService
        
        // Get the session token for authentication
        guard let sessionToken = try await clerk.getSessionToken() else {
            logger.error("No session token available for authentication")
            throw NetworkError.unauthorized
        }
        
        // Create request body
        let requestBody = UserUpdateRequest(
            email: email,
            firstName: firstName,
            lastName: lastName
        )
        
        logger.notice("Making PATCH request to /api/user with Bearer token")
        
        // Make the request to update user info
        let _: UserUpdateResponse = try await networkService.patch(
            endpoint: .userUpdate,
            body: requestBody,
            queryItems: nil,
            authToken: sessionToken
        )
                
        // After successful update, fetch updated user data
        await fetchUserData(networkService: networkService, clerkService: clerk)
        
        logger.notice("User information updated successfully")
    }
    
}

