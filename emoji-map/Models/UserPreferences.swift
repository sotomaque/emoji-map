import Foundation
import CoreLocation
import os.log


// User preferences container
class UserPreferences: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasLaunchedBefore: Bool = false
    @Published var favoritePlaceIds: Set<String> = []
    @Published var placeRatings: [String: Int] = [:]
    
    // User data from API
    @Published var userId: String?
    @Published var userEmail: String?
    
    private let onboardingKey = "has_completed_onboarding"
    private let hasLaunchedBeforeKey = "has_launched_before"
    private let favoritePlacesKey = "favorite_place_ids"
    private let placeRatingsKey = "place_ratings"
    private let userIdKey = "user_id"
    private let userEmailKey = "user_email"
    
    let userDefaults: UserDefaults
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "UserPreferences")
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadOnboardingStatus()
        loadLaunchStatus()
        loadFavoritePlaces()
        loadPlaceRatings()
        loadUserData()
        
        // Mark that the app has been launched
        if !hasLaunchedBefore {
            markAsLaunched()
        }
    }
    
 
    // MARK: - Onboarding Status
    
    func markOnboardingAsCompleted() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
        userDefaults.synchronize()
    }
    
    private func loadOnboardingStatus() {
        hasCompletedOnboarding = userDefaults.bool(forKey: onboardingKey)
    }
    
    // MARK: - Has Launched Before (to avoid showing splash and onboarding both on initial launch)

    func markAsLaunched() {
        hasLaunchedBefore = true
        userDefaults.set(true, forKey: hasLaunchedBeforeKey)
        userDefaults.synchronize()
    }
    
    private func loadLaunchStatus() {
        hasLaunchedBefore = userDefaults.bool(forKey: hasLaunchedBeforeKey)
    }
    
    // MARK: - Favorite Places
    
    /// Toggle favorite status for a place
    /// - Parameter placeId: The ID of the place to toggle
    /// - Returns: The new favorite status (true if favorited, false if unfavorited)
    func toggleFavorite(placeId: String) -> Bool {
        let isFavorite: Bool
        
        if favoritePlaceIds.contains(placeId) {
            // Remove from favorites
            favoritePlaceIds.remove(placeId)
            logger.notice("Removed place from favorites: \(placeId)")
            isFavorite = false
        } else {
            // Add to favorites
            favoritePlaceIds.insert(placeId)
            logger.notice("Added place to favorites: \(placeId)")
            isFavorite = true
        }
        
        // Save to UserDefaults
        saveFavoritePlaces()
        
        // Log the full list of favorites
        logger.notice("Current favorites list (\(self.favoritePlaceIds.count) items): \(Array(self.favoritePlaceIds).joined(separator: ", "))")
        
        // Update the database in the background if user is logged in
        if let userId = self.userId {
            updateFavoriteInDatabase(userId: userId, placeId: placeId, isFavorite: isFavorite)
        } else {
            logger.notice("User not logged in, skipping database update for favorite")
        }
        
        return isFavorite
    }
    
    /// Update favorite status in the database (non-blocking background request)
    /// - Parameters:
    ///   - userId: The user ID
    ///   - placeId: The place ID
    ///   - isFavorite: Whether the place is favorited
    private func updateFavoriteInDatabase(userId: String, placeId: String, isFavorite: Bool) {
        // Create a background task to update the database
        Task.detached(priority: .background) {
            do {
                // Get the network service from the service container
                let networkService = ServiceContainer.shared.networkService
                
                // Create the request body
                let favoriteRequest = FavoriteRequest(
                    userId: userId,
                    placeId: placeId,
                    isFavorite: isFavorite
                )
                
                // Log the request
                self.logger.notice("Sending favorite update to API: userId=\(userId), placeId=\(placeId), isFavorite=\(isFavorite)")
                
                // Make the request to the favorite endpoint
                let _: EmptyResponse = try await networkService.post(
                    endpoint: .favorite,
                    body: favoriteRequest,
                    queryItems: nil,
                    authToken: nil
                )
                
                // Log success
                self.logger.notice("Successfully updated favorite in database: placeId=\(placeId), isFavorite=\(isFavorite)")
            } catch {
                // Just log the error, don't show it to the user since this is a background operation
                self.logger.error("Failed to update favorite in database: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check if a place is favorited
    /// - Parameter placeId: The ID of the place to check
    /// - Returns: True if the place is favorited, false otherwise
    func isFavorite(placeId: String) -> Bool {
        return favoritePlaceIds.contains(placeId)
    }
    
    /// Save favorite places to UserDefaults
    private func saveFavoritePlaces() {
        userDefaults.set(Array(self.favoritePlaceIds), forKey: favoritePlacesKey)
        userDefaults.synchronize()
    }
    
    /// Load favorite places from UserDefaults
    private func loadFavoritePlaces() {
        if let savedFavorites = userDefaults.stringArray(forKey: favoritePlacesKey) {
            favoritePlaceIds = Set(savedFavorites)
            logger.notice("Loaded \(self.favoritePlaceIds.count) favorite places from UserDefaults")
        }
    }
    
    // MARK: - Place Ratings
    
    /// Set a rating for a place
    /// - Parameters:
    ///   - placeId: The ID of the place to rate
    ///   - rating: The rating value (1-5)
    func setRating(placeId: String, rating: Int) {
        // Ensure rating is within valid range
        let validRating = max(0, min(5, rating))
        
        // Update the rating
        placeRatings[placeId] = validRating
        
        // Save to UserDefaults
        savePlaceRatings()
        
        logger.notice("Set rating \(validRating) for place: \(placeId)")
    }
    
    /// Get the user's rating for a place
    /// - Parameter placeId: The ID of the place to check
    /// - Returns: The rating (0-5, where 0 means no rating)
    func getRating(placeId: String) -> Int {
        return placeRatings[placeId] ?? 0
    }
    
    /// Save place ratings to UserDefaults
    private func savePlaceRatings() {
        userDefaults.set(placeRatings, forKey: placeRatingsKey)
        userDefaults.synchronize()
    }
    
    /// Load place ratings from UserDefaults
    private func loadPlaceRatings() {
        if let savedRatings = userDefaults.dictionary(forKey: placeRatingsKey) as? [String: Int] {
            placeRatings = savedRatings
            logger.notice("Loaded \(self.placeRatings.count) place ratings from UserDefaults")
        }
    }
    
    // MARK: - User Data
    
    /// Load user data from UserDefaults
    private func loadUserData() {
        userId = userDefaults.string(forKey: userIdKey)
        userEmail = userDefaults.string(forKey: userEmailKey)
    }
    
    /// Save user ID and email to UserDefaults
    /// - Parameters:
    ///   - id: The user ID
    ///   - email: The user email
    func saveUserData(id: String, email: String) {
        userId = id
        userEmail = email
        
        userDefaults.set(id, forKey: userIdKey)
        userDefaults.set(email, forKey: userEmailKey)
        userDefaults.synchronize()
        
        logger.notice("Saved user data - ID: \(id), Email: \(email)")
    }
    
    /// Synchronize favorites with API data
    /// - Parameter apiFavorites: Array of Favorite objects from the API
    func syncFavoritesWithAPI(apiFavorites: [Favorite]) {
        // Create a set of place IDs from the API favorites
        let apiPlaceIds = Set(apiFavorites.map { $0.placeId })
        
        // Log the differences
        let newFavorites = apiPlaceIds.subtracting(favoritePlaceIds)
        let removedFavorites = favoritePlaceIds.subtracting(apiPlaceIds)
        
        if !newFavorites.isEmpty {
            logger.notice("Adding \(newFavorites.count) new favorites from API: \(Array(newFavorites).joined(separator: ", "))")
        }
        
        if !removedFavorites.isEmpty {
            logger.notice("Removing \(removedFavorites.count) favorites not in API: \(Array(removedFavorites).joined(separator: ", "))")
        }
        
        // Update the favorites set with the API data
        favoritePlaceIds = apiPlaceIds
        
        // Save to UserDefaults
        saveFavoritePlaces()
        
        logger.notice("Synchronized favorites with API - Total favorites: \(self.favoritePlaceIds.count)")
    }
    
    // MARK: - Data Reset
    
    func resetAllData() {
        // Clear all data from memory
        hasCompletedOnboarding = false
        hasLaunchedBefore = false
        favoritePlaceIds.removeAll()
        placeRatings.removeAll()
        
        // Clear all data from UserDefaults
        userDefaults.removeObject(forKey: onboardingKey)
        userDefaults.removeObject(forKey: hasLaunchedBeforeKey)
        userDefaults.removeObject(forKey: favoritePlacesKey)
        userDefaults.removeObject(forKey: placeRatingsKey)
        userDefaults.removeObject(forKey: userIdKey)
        userDefaults.removeObject(forKey: userEmailKey)
        userDefaults.synchronize()
        
        // Notify observers
        objectWillChange.send()
        
        logger.notice("All settings have been reset")
    }
} 
