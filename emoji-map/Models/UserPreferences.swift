import Foundation
import CoreLocation

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
    
    private let favoritesKey = "user_favorites"
    private let ratingsKey = "user_ratings"
    let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFavorites()
        loadRatings()
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
} 