//
//  User.swift
//  emoji-map
//
//  Created by Enrique on 3/14/25.
//

import Foundation

/// Model representing a favorite place
struct Favorite: Codable, Identifiable {
    let id: String
    let userId: String
    let placeId: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case placeId
        case createdAt
    }
    
    // Custom initializer
    init(id: String, userId: String, placeId: String, createdAt: Date?) {
        self.id = id
        self.userId = userId
        self.placeId = placeId
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        placeId = try container.decode(String.self, forKey: .placeId)
        
        // Handle date decoding with ISO8601 format
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
    }
}

/// Model representing a user rating
struct Rating: Codable, Identifiable {
    let id: String
    let userId: String
    let placeId: String
    let rating: Int
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case placeId
        case rating
        case createdAt
        case updatedAt
    }
    
    // Custom initializer
    init(id: String, userId: String, placeId: String, rating: Int, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.userId = userId
        self.placeId = placeId
        self.rating = rating
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        placeId = try container.decode(String.self, forKey: .placeId)
        rating = try container.decode(Int.self, forKey: .rating)
        
        // Handle date decoding with ISO8601 format
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        // Handle date decoding with ISO8601 format
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            updatedAt = formatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
}

/// Model representing a user from the API
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let imageUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    let favorites: [Favorite]
    let ratings: [Rating]
    
    // CodingKeys to match the API response
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case firstName
        case lastName
        case imageUrl
        case createdAt
        case updatedAt
        case favorites
        case ratings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        
        // Handle date decoding with ISO8601 format
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        // Handle date decoding with ISO8601 format
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            updatedAt = formatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
        
        // Handle favorites array which may or may not be present
        if container.contains(.favorites) {
            // Decode as FavoriteResponse array first, then convert to Favorite array
            let favoriteResponses = try container.decode([FavoriteResponse].self, forKey: .favorites)
            favorites = favoriteResponses.map { $0.toFavorite }
        } else {
            favorites = []
        }
        
        // Handle ratings array which may or may not be present
        if container.contains(.ratings) {
            // Decode as RatingResponse array first, then convert to Rating array
            let ratingResponses = try container.decode([RatingResponse].self, forKey: .ratings)
            ratings = ratingResponses.map { $0.toRating }
        } else {
            ratings = []
        }
    }
    
    // Convenience initializer for creating a User from individual properties
    init(id: String, email: String, username: String?, firstName: String?, lastName: String?, 
         imageUrl: String?, createdAt: Date?, updatedAt: Date?, favorites: [Favorite] = [], ratings: [Rating] = []) {
        self.id = id
        self.email = email
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.favorites = favorites
        self.ratings = ratings
    }
}

/// Response model for a favorite place
struct FavoriteResponse: Codable {
    let id: String
    let userId: String
    let placeId: String
    let createdAt: String?
    
    // CodingKeys to match the API response
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case placeId
        case createdAt
    }
    
    // Convert to Favorite model
    var toFavorite: Favorite {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdDate = createdAt.flatMap { formatter.date(from: $0) }
        
        return Favorite(
            id: id,
            userId: userId,
            placeId: placeId,
            createdAt: createdDate
        )
    }
}

/// Response model for a user rating
struct RatingResponse: Codable {
    let id: String
    let userId: String
    let placeId: String
    let rating: Int
    let createdAt: String?
    let updatedAt: String?
    
    // CodingKeys to match the API response
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case placeId
        case rating
        case createdAt
        case updatedAt
    }
    
    // Convert to Rating model
    var toRating: Rating {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdDate = createdAt.flatMap { formatter.date(from: $0) }
        let updatedDate = updatedAt.flatMap { formatter.date(from: $0) }
        
        return Rating(
            id: id,
            userId: userId,
            placeId: placeId,
            rating: rating,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

/// Response from the user API endpoint
struct UserResponse: Codable {
    let user: UserData
    
    // Convert the response to a User model
    var toUser: User {
        return user.toUser
    }
}

/// User data from the API response
struct UserData: Codable {
    let id: String
    let email: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let imageUrl: String?
    let createdAt: String?
    let updatedAt: String?
    let favorites: [FavoriteResponse]?
    let ratings: [RatingResponse]?
    
    // Convert to User model
    var toUser: User {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdDate = createdAt.flatMap { formatter.date(from: $0) }
        let updatedDate = updatedAt.flatMap { formatter.date(from: $0) }
        
        // Convert favorite responses to Favorite models
        let favoriteModels = favorites?.map { $0.toFavorite } ?? []
        
        // Convert rating responses to Rating models
        let ratingModels = ratings?.map { $0.toRating } ?? []
        
        return User(
            id: id,
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName,
            imageUrl: imageUrl,
            createdAt: createdDate,
            updatedAt: updatedDate,
            favorites: favoriteModels,
            ratings: ratingModels
        )
    }
}

/// Empty response for endpoints that might return empty responses
struct EmptyResponse: Codable {
    let success: Bool
    let message: String?
    
    static let empty = EmptyResponse(success: true, message: nil)
}

/// Model for favorite request to the API
struct FavoriteRequest: Codable {
    let userId: String
    let placeId: String
    let isFavorite: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId
        case placeId
        case isFavorite
    }
}

/// Model for rating request to the API
struct RatingRequest: Codable {
    let userId: String
    let placeId: String
    let rating: Int
    
    enum CodingKeys: String, CodingKey {
        case userId
        case placeId
        case rating
    }
}

/// Response from the favorite and rating API endpoints
struct PlaceActionResponse: Codable {
    let message: String
    let place: PlaceResponseData?
    
    struct PlaceResponseData: Codable {
        let id: String
        let name: String?
        let description: String?
        let latitude: Double?
        let longitude: Double?
        let createdAt: String?
        let updatedAt: String?
    }
} 
