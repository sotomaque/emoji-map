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
    @Published var places: [Place] = []
    @Published var filteredPlaces: [Place] = []
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
    
    // Filter state
    @Published var selectedPriceLevels: Set<Int> = []
    @Published var minimumRating: Int = 0
    @Published var useLocalRatings: Bool = false
    @Published var showOpenNowOnly: Bool = false
    
    // Computed property to check if all price levels are selected or none are selected
    var allPriceLevelsSelected: Bool {
        // If no price levels are selected, it's the same as all being selected (no filtering)
        if selectedPriceLevels.isEmpty {
            return true
        }
        
        // Otherwise, check if all 4 price levels are selected
        return selectedPriceLevels.count == 4 && 
               selectedPriceLevels.contains(1) && 
               selectedPriceLevels.contains(2) && 
               selectedPriceLevels.contains(3) && 
               selectedPriceLevels.contains(4)
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
    
    // Computed property to check if we have network-dependent filters
    var hasNetworkDependentFilters: Bool {
        // Price level filters require network request
        let hasPriceLevelFilters = !allPriceLevelsSelected
        
        // Open now filter requires network request
        let hasOpenNowFilter = showOpenNowOnly
        
        // Google Maps rating filter requires network request (but not local ratings)
        let hasGoogleRatingFilter = minimumRating > 0 && !useLocalRatings
        
        return hasPriceLevelFilters || hasOpenNowFilter || hasGoogleRatingFilter
    }
    
    // Map state
    @Published var visibleRegion: MKCoordinateRegion?
    private var lastFetchedRegion: MKCoordinateRegion?
    private var regionChangeDebounceTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var isSuperZoomedIn: Bool = false // Track super zoomed in state
    
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
                
                logger.notice("Making authenticated request to /api/user with Bearer token")
                
                // Make the request to the user endpoint with token-based authentication
                let userResponse: UserResponse = try await networkService.fetch(
                    endpoint: .user,
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
        
        if isSuperZoomedIn {
            logger.notice("🔍 Super zoomed in! Average span: \(averageSpan)")
        }
        
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
                    logger.notice("Fetching places by categories due to region change: \(self.selectedCategoryKeys)")
                    fetchPlacesByCategories(at: center)
                } else {
                    // Otherwise use the regular nearby places endpoint
                    logger.notice("Fetching all nearby places due to region change")
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
            places.removeAll()
            logger.notice("Cleared existing places for full refresh")
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
            logger.notice("Refreshing places by categories: \(self.selectedCategoryKeys)")
            fetchPlacesByCategories(at: location)
        } else {
            // Otherwise use the regular nearby places endpoint
            logger.notice("Refreshing all nearby places")
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
        
        // Update filtered places based on the current state
        updateFilteredPlaces()
    }
    
    /// Toggle all categories mode
    func toggleAllCategories() {
        // If already in "All" mode, do nothing (prevent deselection)
        if isAllCategoriesMode {
            logger.notice("All categories mode already active, ignoring toggle")
            return
        }
        
        // Otherwise, enable "All" mode
        isAllCategoriesMode = true
        
        // Clear selected categories when "All" is selected
        selectedCategoryKeys.removeAll()
        logger.notice("All categories mode enabled, cleared selected categories")
        
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
            
            // Fetch all nearby places when switching to "All" mode
            if let location = visibleRegion?.center ?? locationManager.lastLocation?.coordinate {
                fetchNearbyPlaces(at: location)
            }
        } else {
            isAllCategoriesMode = false
            
            // Log when not in "all" mode with the selected key
            logger.notice("Not all - Category key selected: \(key) \(emoji)")
            
            // Fetch places by categories when we have categories selected
            fetchPlacesByCategories()
        }
        
        logger.notice("Selected keys: \(self.selectedCategoryKeys)")
        applyFilters()
    }
    
    /// Apply filters to places based on selected categories
    func applyFilters() {
        logger.notice("Applying filters: price levels = \(self.selectedPriceLevels)")
        
        // Create the request body with the selected filters
        let location = visibleRegion?.center ?? locationManager.lastLocation?.coordinate
        
        guard let location = location else {
            errorMessage = "Unable to determine your location"
            logger.error("Apply filters failed: No location available")
            return
        }
        
        // Reset filteredPlaces when filters change
        filteredPlaces.removeAll()
        logger.notice("Reset filteredPlaces due to filter change")
        
        // Refresh places with the new filters
        Task {
            await fetchPlacesWithFilters(at: location)
        }
    }
    
    /// Fetch places with applied filters
    private func fetchPlacesWithFilters(at location: CLLocationCoordinate2D) async {
        guard !isLoading else {
            logger.notice("Skipping fetch with filters - already loading")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // If we don't have network-dependent filters, just apply local filtering
        if !hasNetworkDependentFilters {
            logger.notice("Using local filtering only (no network-dependent filters)")
            updateFilteredPlaces()
            isLoading = false
            return
        }
        
        do {
            // If all price levels are selected or none are selected, treat it as if no price level filter is applied
            let priceLevelsToUse: [Int]?
            if allPriceLevelsSelected {
                logger.notice("No price level filtering applied (all levels selected or none selected)")
                priceLevelsToUse = nil
            } else {
                logger.notice("Applying price level filter: \(Array(self.selectedPriceLevels).sorted())")
                priceLevelsToUse = Array(selectedPriceLevels).sorted()
            }
            
            // Determine if we should include minimum rating in the request
            // Only include it when using Google Maps ratings (not local ratings)
            let minimumRatingToUse: Int?
            if !useLocalRatings && minimumRating > 0 {
                minimumRatingToUse = minimumRating
                logger.notice("Applying Google Maps minimum rating filter server-side: \(self.minimumRating)")
            } else {
                minimumRatingToUse = nil
                if minimumRating > 0 && useLocalRatings {
                    logger.notice("Using local ratings filter: \(self.minimumRating) (will be applied client-side)")
                } else {
                    logger.notice("No rating filter applied")
                }
            }
            
            // Create request body with filters
            let requestBody = PlaceSearchRequest(
                keys: isAllCategoriesMode ? nil : Array(selectedCategoryKeys),
                openNow: showOpenNowOnly ? true : nil, // Use the showOpenNowOnly filter
                priceLevels: priceLevelsToUse,
                radius: 5000, // Default radius
                location: PlaceSearchRequest.LocationCoordinate(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                bypassCache: true, // Always bypass cache when applying filters
                maxResultCount: nil,
                minimumRating: minimumRatingToUse // Add the minimum rating parameter
            )
            
            logger.notice("Fetching places with filters at location: \(location.latitude), \(location.longitude)")
            
            let response: PlacesResponse = try await placesService.fetchWithFilters(
                location: location,
                requestBody: requestBody
            )
            
            // Log the response details
            logger.notice("Response from API: count=\(response.count), cacheHit=\(response.cacheHit), results.count=\(response.results.count)")
            
            // Merge new filtered places with existing filtered places
            mergeFilteredPlaces(response.results)
            
            if !useLocalRatings && minimumRating > 0 {
                logger.notice("Places already filtered by Google Maps rating \(self.minimumRating)+ server-side")
            }
            
            logger.notice("Successfully fetched \(response.results.count) places with filters")
            
            // Ensure loading indicator is turned off
            isLoading = false
        } catch {
            logger.error("Failed to fetch places with filters: \(error.localizedDescription)")
            errorMessage = "Failed to fetch places: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Fetch places by selected category keys
    private func fetchPlacesByCategories(at location: CLLocationCoordinate2D? = nil) {
        // Only proceed if we have categories selected
        guard !selectedCategoryKeys.isEmpty else {
            logger.notice("No categories selected, skipping category-specific fetch")
            return
        }
        
        // Cancel any existing fetch task
        fetchTask?.cancel()
        
        // Determine the location to use
        let fetchLocation = location ?? visibleRegion?.center ?? locationManager.lastLocation?.coordinate
        
        // Only proceed if we have a location
        guard let fetchLocation = fetchLocation else {
            logger.error("Cannot fetch places by categories: No location available")
            return
        }
        
        // Log if we're bypassing cache due to being super zoomed in
        if isSuperZoomedIn {
            logger.notice("Super zoomed in mode - adding bypassCache parameter to categories request")
        }
        
        logger.notice("Fetching places by categories: \(self.selectedCategoryKeys) at location: \(fetchLocation.latitude), \(fetchLocation.longitude)")
        
        // Create a new fetch task
        fetchTask = Task {
            do {
                let categoryKeysArray = Array(selectedCategoryKeys) 
                let fetchedPlaces = try await placesService.fetchPlacesByCategories(
                    location: fetchLocation,
                    categoryKeys: categoryKeysArray,
                    bypassCache: isSuperZoomedIn // Add bypassCache parameter
                )
                
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                // Merge new places with existing places
                mergePlaces(fetchedPlaces)
                logger.notice("Fetched \(fetchedPlaces.count) places by categories, total places now: \(self.places.count)")
                
                // If we have network-dependent filters, fetch filtered places
                if hasNetworkDependentFilters {
                    // Fetch filtered places with the same location
                    await fetchPlacesWithFilters(at: fetchLocation)
                } else {
                    // Otherwise just apply local filtering
                    updateFilteredPlaces()
                }
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
        
        // Log if we're bypassing cache due to being super zoomed in
        if isSuperZoomedIn {
            logger.notice("Super zoomed in mode - adding bypassCache parameter to request")
        }
        
        logger.notice("Fetching nearby places at \(coordinate.latitude), \(coordinate.longitude)")
        
        // Create a new fetch task
        fetchTask = Task {
            do {
                let fetchedPlaces = try await placesService.fetchNearbyPlaces(
                    location: coordinate,
                    useCache: useCache && !isSuperZoomedIn // Don't use cache if super zoomed in
                )
                
                // Check if the task was cancelled
                if Task.isCancelled { return }
                
                // Merge new places with existing places instead of replacing
                mergePlaces(fetchedPlaces)
                logger.notice("Fetched \(fetchedPlaces.count) places, total places now: \(self.places.count)")
                
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
    
    /// Merge new filtered places with existing filtered places, avoiding duplicates
    private func mergeFilteredPlaces(_ newPlaces: [Place]) {
        // Create a dictionary of existing filtered places by ID for efficient lookup
        let existingPlacesById = Dictionary(uniqueKeysWithValues: filteredPlaces.map { ($0.id, $0) })
        
        // Count before adding
        let countBefore = filteredPlaces.count
        
        // Add only places that don't already exist
        for place in newPlaces {
            if existingPlacesById[place.id] == nil {
                filteredPlaces.append(place)
            }
        }
        
        // Log how many new places were added
        let addedCount = filteredPlaces.count - countBefore
        if addedCount > 0 {
            logger.notice("Added \(addedCount) new unique filtered places, total now: \(self.filteredPlaces.count)")
        } else {
            logger.notice("No new unique filtered places to add, total remains: \(self.filteredPlaces.count)")
        }
    }
    
    /// Update the filtered places based on current filter settings
    public func updateFilteredPlaces() {
        // Start with all places
        var filtered = places
        
        // Apply favorites filter if enabled
        if showFavoritesOnly {
            filtered = filtered.filter { userPreferences.isFavorite(placeId: $0.id) }
            logger.notice("Filtered to \(filtered.count) favorite places")
        }
        
        // Apply category filter if not in all categories mode
        if !isAllCategoriesMode && !selectedCategoryKeys.isEmpty {
            filtered = filtered.filter { place in
                // Check if the place has any emoji with matching category
                place.emoji.contains(where: { character in
                    let singleEmoji = String(character)
                    if let key = CategoryMappings.getKeyForEmoji(singleEmoji) {
                        return selectedCategoryKeys.contains(key)
                    }
                    return false
                })
            }
            logger.notice("Filtered to \(filtered.count) places with selected categories")
        }
        
        // Apply rating filter if set
        if minimumRating > 0 {
            if useLocalRatings {
                // Use local user ratings
                filtered = filtered.filter { place in
                    let userRating = userPreferences.getRating(placeId: place.id)
                    return Double(userRating) >= Double(self.minimumRating)
                }
                logger.notice("Filtered to \(filtered.count) places with local rating >= \(self.minimumRating)")
            } else {
                // Use Google ratings
                filtered = filtered.filter { place in 
                    if let rating = place.rating {
                        return rating >= Double(self.minimumRating)
                    }
                    return false
                }
                logger.notice("Filtered to \(filtered.count) places with Google rating >= \(self.minimumRating)")
            }
        }
        
        // Apply price level filter if any are selected (and not all are selected)
        if !allPriceLevelsSelected {
            filtered = filtered.filter { place in
                if let priceLevel = place.priceLevel {
                    return selectedPriceLevels.contains(priceLevel)
                }
                // If no price level is specified, include it if price level 1 is selected
                return selectedPriceLevels.contains(1)
            }
            logger.notice("Filtered to \(filtered.count) places with selected price levels")
        }
        
        // Set the filtered places
        filteredPlaces = filtered
    }
    
    /// Set all price levels (1-4) as selected
    func selectAllPriceLevels() {
        selectedPriceLevels = [1, 2, 3, 4]
        logger.notice("All price levels selected")
    }
    
    /// Clear all price levels and select only the specified level
    func selectOnlyPriceLevel(_ level: Int) {
        selectedPriceLevels = [level]
        logger.notice("Selected only price level \(level)")
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
} 
