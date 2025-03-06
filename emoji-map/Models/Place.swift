//
//  Place.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import MapKit

struct Place: Identifiable {
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
    
    // Convenience method to check if the place has a valid rating
    var hasRating: Bool {
        return rating != nil && rating! > 0
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
        return String(format: "%.1f ★", rating)
    }
    
    // Convenience method to get a formatted open status
    var openStatus: String {
        guard let isOpen = openNow else { return "Hours not available" }
        return isOpen ? "Open now" : "Closed"
    }
}
