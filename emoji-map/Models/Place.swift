//
//  Place.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import MapKit

struct Place: Identifiable, Codable {
    let id = UUID()
    let placeId: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let description: String
    let priceLevel: Int?
    let openNow: Bool?
    let rating: Double?
    
    init(
        placeId: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        category: String,
        description: String? = nil,
        priceLevel: Int? = nil,
        openNow: Bool? = nil,
        rating: Double? = nil
    ) {
        self.placeId = placeId.isEmpty ? UUID().uuidString : placeId // Fallback for empty placeId
        self.name = name.isEmpty ? "Unnamed Place" : name // Fallback for empty name
        self.coordinate = coordinate
        self.category = category
        self.description = description ?? "No description available" // Fallback for nil description
        self.priceLevel = priceLevel
        self.openNow = openNow
        self.rating = rating
        
        // Validate coordinate
        assert(
            coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
            coordinate.longitude >= -180 && coordinate.longitude <= 180,
            "Invalid coordinates: \(coordinate.latitude), \(coordinate.longitude)"
        )
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, placeId, name, coordinate, category, description, priceLevel, openNow, rating
    }
    
    enum CoordinateKeys: String, CodingKey {
        case latitude, longitude
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(placeId, forKey: .placeId)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(description, forKey: .description)
        try container.encode(priceLevel, forKey: .priceLevel)
        try container.encode(openNow, forKey: .openNow)
        try container.encode(rating, forKey: .rating)
        
        // Encode coordinate as nested container
        var coordinateContainer = container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
        try coordinateContainer.encode(coordinate.latitude, forKey: .latitude)
        try coordinateContainer.encode(coordinate.longitude, forKey: .longitude)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id is generated in the main initializer
        placeId = try container.decode(String.self, forKey: .placeId)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        openNow = try container.decodeIfPresent(Bool.self, forKey: .openNow)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        
        // Decode coordinate from nested container
        let coordinateContainer = try container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
        let latitude = try coordinateContainer.decode(Double.self, forKey: .latitude)
        let longitude = try coordinateContainer.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Convenience method to check if the place has a valid rating
    var hasRating: Bool {
        guard let rating = rating else { return false }
        return rating > 0
    }
    
    // Convenience method to get a formatted price level string
    var formattedPriceLevel: String {
        guard let level = priceLevel else { return "Price not available" }
        
        switch level {
        case 1: return "$"
        case 2: return "$$"
        case 3: return "$$$"
        case 4: return "$$$$"
        default: return "Price not available"
        }
    }
    
    // Convenience method to get a formatted rating string
    var formattedRating: String {
        guard let rating = rating else { return "Not rated" }
        return String(format: "%.1f", rating)
    }
    
    // Convenience property to get the open status as a string
    var openStatus: String {
        guard let isOpen = openNow else { return "Unknown" }
        return isOpen ? "Open Now" : "Closed"
    }
}
