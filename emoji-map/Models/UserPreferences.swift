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
    @MainActor
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
    @MainActor
    private func updateFavoriteInDatabase(userId: String, placeId: String, isFavorite: Bool) {
        // Create a background task to update the database
        Task.detached(priority: .background) {
            do {
                // Get the network service and clerk service from the service container
                let networkService = await ServiceContainer.shared.networkService
                let clerkService = await ServiceContainer.shared.clerkService
                
                // Get session token for authorization
                var sessionToken: String? = nil
                do {
                    sessionToken = try await clerkService.getSessionToken()
                    if let token = sessionToken {
                        self.logger.notice("Retrieved session token for favorite update: \(String(token.prefix(15)))...")
                    } else {
                        self.logger.notice("No session token available despite user being authenticated")
                    }
                } catch {
                    self.logger.error("Error retrieving session token: \(error.localizedDescription)")
                }
                
                // Create the request body without userId (will be derived from token on server)
                let favoriteRequest = FavoriteRequest(
                    userId: userId,  // Keep userId for now for backward compatibility
                    placeId: placeId,
                    isFavorite: isFavorite
                )
                
                // Log the request
                self.logger.notice("Sending favorite update to API: placeId=\(placeId), isFavorite=\(isFavorite)")
                
                // Make the request to update the favorite status with the auth token
                let _: FavoriteResponse = try await networkService.post(
                    endpoint: .favorite,
                    body: favoriteRequest,
                    queryItems: nil,
                    authToken: sessionToken
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
    @MainActor
    func setRating(placeId: String, rating: Int) {
        // Ensure rating is within valid range
        let validRating = max(0, min(5, rating))
        
        // Update the rating
        placeRatings[placeId] = validRating
        
        // Save to UserDefaults
        savePlaceRatings()
        
        logger.notice("Set rating \(validRating) for place: \(placeId)")
        
        // Update the database in the background if user is logged in
        if let userId = self.userId {
            updateRatingInDatabase(userId: userId, placeId: placeId, rating: validRating)
        } else {
            logger.notice("User not logged in, skipping database update for rating")
        }
    }
    
    /// Update rating in the database (non-blocking background request)
    /// - Parameters:
    ///   - userId: The user ID
    ///   - placeId: The place ID
    ///   - rating: The rating value
    @MainActor
    private func updateRatingInDatabase(userId: String, placeId: String, rating: Int) {
        // Create a background task to update the database
        Task.detached(priority: .background) {
            do {
                // Get the network service and clerk service from the service container
                let networkService = await ServiceContainer.shared.networkService
                let clerkService = await ServiceContainer.shared.clerkService
                
                // Get session token for authorization
                var sessionToken: String? = nil
                do {
                    sessionToken = try await clerkService.getSessionToken()
                    if let token = sessionToken {
                        self.logger.notice("Retrieved session token for rating update: \(String(token.prefix(15)))...")
                    } else {
                        self.logger.notice("No session token available despite user being authenticated")
                    }
                } catch {
                    self.logger.error("Error retrieving session token: \(error.localizedDescription)")
                }
                
                // Create the request body without userId (will be derived from token on server)
                let ratingRequest = RatingRequest(
                    userId: userId,  // Keep userId for now for backward compatibility
                    placeId: placeId,
                    rating: rating
                )
                
                // Log the request
                self.logger.notice("Sending rating update to API: placeId=\(placeId), rating=\(rating)")
                
                // Make the request to update the rating with the auth token
                let _: RatingResponse = try await networkService.post(
                    endpoint: .rating,
                    body: ratingRequest,
                    queryItems: nil,
                    authToken: sessionToken
                )
                
                // Log success
                self.logger.notice("Successfully updated rating in database: placeId=\(placeId), rating=\(rating)")
            } catch {
                // Just log the error, don't show it to the user since this is a background operation
                self.logger.error("Failed to update rating in database: \(error.localizedDescription)")
            }
        }
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
    
    /// Synchronize ratings with API data
    /// - Parameter apiRatings: Array of Rating objects from the API
    func syncRatingsWithAPI(apiRatings: [Rating]) {
        // Log the incoming API ratings
        logger.notice("Syncing \(apiRatings.count) ratings from API")
        
        // Create a dictionary of place IDs to ratings from the API
        var apiRatingsDict = [String: Int]()
        for rating in apiRatings {
            apiRatingsDict[rating.placeId] = rating.rating
            logger.notice("API Rating: Place ID: \(rating.placeId), Rating: \(rating.rating)")
        }
        
        // Log the current local ratings
        logger.notice("Current local ratings count: \(self.placeRatings.count)")
        
        // Track changes for logging
        var newRatings = 0
        var updatedRatings = 0
        var removedRatings = 0
        
        // Track places that have ratings in the API but not locally
        for (placeId, rating) in apiRatingsDict {
            if let localRating = placeRatings[placeId] {
                if localRating != rating {
                    logger.notice("Updating rating for place \(placeId) from \(localRating) to \(rating)")
                    updatedRatings += 1
                }
            } else {
                logger.notice("Adding new rating for place \(placeId): \(rating)")
                newRatings += 1
            }
        }
        
        // Track places that have ratings locally but not in the API
        for (placeId, _) in placeRatings {
            if apiRatingsDict[placeId] == nil {
                logger.notice("Removing rating for place \(placeId) not in API")
                removedRatings += 1
            }
        }
        
        // Update the ratings dictionary with the API data
        placeRatings = apiRatingsDict
        
        // Save to UserDefaults
        savePlaceRatings()
        
        // Log the final state
        logger.notice("Final ratings after sync: \(self.placeRatings.count)")
        for (placeId, rating) in self.placeRatings {
            logger.notice("  Synced Rating: Place ID: \(placeId), Rating: \(rating)")
        }
        
        logger.notice("Synchronized ratings with API - Added: \(newRatings), Updated: \(updatedRatings), Removed: \(removedRatings), Total: \(self.placeRatings.count)")
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
