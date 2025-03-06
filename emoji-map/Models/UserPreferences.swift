import Foundation
import CoreLocation

// Enum for distance units
enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case miles = "Miles"
    case kilometers = "Kilometers"
    
    var id: String { self.rawValue }
    
    // Conversion factor from meters
    var conversionFactor: Double {
        switch self {
        case .miles: return 0.000621371 // meters to miles
        case .kilometers: return 0.001 // meters to kilometers
        }
    }
    
    // Format a distance in meters according to the unit
    func formatDistance(_ distanceInMeters: Double) -> String {
        let convertedDistance = distanceInMeters * conversionFactor
        
        if convertedDistance < 0.1 {
            // For very short distances, show in feet or meters
            switch self {
            case .miles:
                let feet = distanceInMeters * 3.28084
                return "\(Int(feet))ft away"
            case .kilometers:
                return "\(Int(distanceInMeters))m away"
            }
        } else if convertedDistance < 10 {
            // For medium distances, show with one decimal place
            let unit = self == .miles ? "mi" : "km"
            return String(format: "%.1f \(unit) away", convertedDistance)
        } else {
            // For longer distances, show as whole numbers
            let unit = self == .miles ? "mi" : "km"
            return "\(Int(convertedDistance)) \(unit) away"
        }
    }
}

// Model to store user ratings for places
struct PlaceRating: Codable, Identifiable, Equatable {
    let id: UUID
    let placeId: String
    let rating: Int // 1-5 stars
    let timestamp: Date
    
    init(placeId: String, rating: Int) {
        self.id = UUID()
        self.placeId = placeId
        self.rating = min(max(rating, 1), 5) // Ensure rating is between 1-5
        self.timestamp = Date()
    }
    
    static func == (lhs: PlaceRating, rhs: PlaceRating) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model to store favorite places
struct FavoritePlace: Codable, Identifiable, Equatable {
    let id: UUID
    let placeId: String
    let name: String
    let category: String
    let coordinate: CoordinateWrapper
    let addedAt: Date
    
    init(place: Place) {
        self.id = UUID()
        self.placeId = place.placeId
        self.name = place.name
        self.category = place.category
        self.coordinate = CoordinateWrapper(place.coordinate)
        self.addedAt = Date()
    }
    
    static func == (lhs: FavoritePlace, rhs: FavoritePlace) -> Bool {
        return lhs.id == rhs.id
    }
}

// User preferences container
class UserPreferences: ObservableObject {
    @Published var favorites: [FavoritePlace] = []
    @Published var ratings: [PlaceRating] = []
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasShownSettingsTooltip: Bool = false
    @Published var distanceUnit: DistanceUnit = .miles
    @Published var defaultMapApp: String = "Apple Maps"
    
    private let favoritesKey = "user_favorites"
    private let ratingsKey = "user_ratings"
    private let onboardingKey = "has_completed_onboarding"
    private let settingsTooltipKey = "has_shown_settings_tooltip"
    private let distanceUnitKey = "distance_unit"
    private let defaultMapAppKey = "default_map_app"
    let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFavorites()
        loadRatings()
        loadOnboardingStatus()
        loadSettingsTooltipStatus()
        loadDistanceUnit()
        loadDefaultMapApp()
    }
    
    // MARK: - Favorites Management
    
    func addFavorite(_ place: Place) {
        // Don't add if already a favorite
        guard !isFavorite(placeId: place.placeId) else { return }
        
        let favorite = FavoritePlace(place: place)
        favorites.append(favorite)
        saveFavorites()
    }
    
    func removeFavorite(placeId: String) {
        favorites.removeAll { $0.placeId == placeId }
        saveFavorites()
    }
    
    func isFavorite(placeId: String) -> Bool {
        return favorites.contains { $0.placeId == placeId }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            userDefaults.set(encoded, forKey: favoritesKey)
            userDefaults.synchronize() // Force immediate save
            print("Saved \(favorites.count) favorites to UserDefaults")
        } else {
            print("Error: Failed to encode favorites")
        }
    }
    
    private func loadFavorites() {
        if let data = userDefaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoritePlace].self, from: data) {
            favorites = decoded
            print("Loaded \(favorites.count) favorites from UserDefaults")
        } else {
            print("No favorites found in UserDefaults or decoding failed")
        }
    }
    
    // Debug method to print current favorites
    func printFavorites() {
        print("Current favorites (\(favorites.count)):")
        for favorite in favorites {
            print("- \(favorite.name) (ID: \(favorite.placeId), Category: \(favorite.category))")
        }
    }
    
    // MARK: - Ratings Management
    
    func ratePlace(placeId: String, rating: Int) {
        // Remove existing rating if present
        ratings.removeAll { $0.placeId == placeId }
        
        // Add new rating
        let newRating = PlaceRating(placeId: placeId, rating: rating)
        ratings.append(newRating)
        saveRatings()
    }
    
    func getRating(for placeId: String) -> Int? {
        return ratings.first { $0.placeId == placeId }?.rating
    }
    
    private func saveRatings() {
        if let encoded = try? JSONEncoder().encode(ratings) {
            userDefaults.set(encoded, forKey: ratingsKey)
        }
    }
    
    private func loadRatings() {
        if let data = userDefaults.data(forKey: ratingsKey),
           let decoded = try? JSONDecoder().decode([PlaceRating].self, from: data) {
            ratings = decoded
        }
    }
    
    // MARK: - Onboarding Status
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
        userDefaults.synchronize()
    }
    
    private func loadOnboardingStatus() {
        hasCompletedOnboarding = userDefaults.bool(forKey: onboardingKey)
    }
    
    // MARK: - Settings Tooltip Status
    
    func markSettingsTooltipAsShown() {
        hasShownSettingsTooltip = true
        userDefaults.set(true, forKey: settingsTooltipKey)
        userDefaults.synchronize()
    }
    
    private func loadSettingsTooltipStatus() {
        hasShownSettingsTooltip = userDefaults.bool(forKey: settingsTooltipKey)
    }
    
    // MARK: - Distance Unit Management
    
    func setDistanceUnit(_ unit: DistanceUnit) {
        distanceUnit = unit
        if let encoded = try? JSONEncoder().encode(unit) {
            userDefaults.set(encoded, forKey: distanceUnitKey)
            userDefaults.synchronize()
        }
    }
    
    private func loadDistanceUnit() {
        if let data = userDefaults.data(forKey: distanceUnitKey),
           let decoded = try? JSONDecoder().decode(DistanceUnit.self, from: data) {
            distanceUnit = decoded
        } else {
            // Default to miles if not set
            distanceUnit = .miles
        }
    }
    
    // MARK: - Default Map App Management
    
    func setDefaultMapApp(_ appName: String) {
        defaultMapApp = appName
        userDefaults.set(appName, forKey: defaultMapAppKey)
        userDefaults.synchronize()
    }
    
    private func loadDefaultMapApp() {
        if let appName = userDefaults.string(forKey: defaultMapAppKey) {
            defaultMapApp = appName
        } else {
            // Default to Apple Maps if not set
            defaultMapApp = "Apple Maps"
        }
    }
    
    // MARK: - Format Distance
    
    func formatDistance(_ distanceInMeters: Double?) -> String {
        guard let distance = distanceInMeters else {
            return "Distance unavailable"
        }
        
        return distanceUnit.formatDistance(distance)
    }
    
    // MARK: - Data Reset
    
    func resetAllData() {
        // Clear all data from memory
        favorites.removeAll()
        ratings.removeAll()
        hasCompletedOnboarding = false
        hasShownSettingsTooltip = false
        distanceUnit = .miles
        defaultMapApp = "Apple Maps"
        
        // Clear all data from UserDefaults
        userDefaults.removeObject(forKey: favoritesKey)
        userDefaults.removeObject(forKey: ratingsKey)
        userDefaults.removeObject(forKey: onboardingKey)
        userDefaults.removeObject(forKey: settingsTooltipKey)
        userDefaults.removeObject(forKey: distanceUnitKey)
        userDefaults.removeObject(forKey: defaultMapAppKey)
        userDefaults.synchronize()
        
        // Notify observers
        objectWillChange.send()
        
        print("All user data has been reset")
    }
} 