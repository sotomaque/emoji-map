import Foundation
import CoreLocation
import os.log


// User preferences container
class UserPreferences: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasLaunchedBefore: Bool = false
    @Published var favoritePlaceIds: Set<String> = []
    
    private let onboardingKey = "has_completed_onboarding"
    private let hasLaunchedBeforeKey = "has_launched_before"
    private let favoritePlacesKey = "favorite_place_ids"
    
    let userDefaults: UserDefaults
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "UserPreferences")
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadOnboardingStatus()
        loadLaunchStatus()
        loadFavoritePlaces()
        
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
        if favoritePlaceIds.contains(placeId) {
            // Remove from favorites
            favoritePlaceIds.remove(placeId)
            logger.notice("Removed place from favorites: \(placeId)")
        } else {
            // Add to favorites
            favoritePlaceIds.insert(placeId)
            logger.notice("Added place to favorites: \(placeId)")
        }
        
        // Save to UserDefaults
        saveFavoritePlaces()
        
        // Log the full list of favorites
        logger.notice("Current favorites list (\(self.favoritePlaceIds.count) items): \(Array(self.favoritePlaceIds).joined(separator: ", "))")
        
        // Return the new status
        return favoritePlaceIds.contains(placeId)
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
    
    // MARK: - Data Reset
    
    func resetAllData() {
        // Clear all data from memory
        hasCompletedOnboarding = false
        hasLaunchedBefore = false
        favoritePlaceIds.removeAll()
        
        // Clear all data from UserDefaults
        userDefaults.removeObject(forKey: onboardingKey)
        userDefaults.removeObject(forKey: hasLaunchedBeforeKey)
        userDefaults.removeObject(forKey: favoritePlacesKey)
        userDefaults.synchronize()
        
        // Notify observers
        objectWillChange.send()
        
        logger.notice("All settings have been reset")
    }
} 
