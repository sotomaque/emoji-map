//
//  Place.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import CoreLocation
import MapKit
import _MapKit_SwiftUI
import SwiftUICore
import SwiftUI

// Place model representing a location with an emoji
struct Place: Identifiable, Codable, Equatable {
    // Required fields from the initial API response
    var id: String
    var emoji: String
    var location: Location
    
    // Optional fields that will be populated from details API
    var photos: [String] = [] // Array of photo URLs, with default empty array
    var displayName: String?
    var rating: Double?
    var reviews: [PlaceDetails.Review]?
    var priceLevel: Int?
    var userRatingCount: Int?
    var openNow: Bool?
    var primaryTypeDisplayName: String?
    var takeout: Bool?
    var delivery: Bool?
    var dineIn: Bool?
    var editorialSummary: String?
    var outdoorSeating: Bool?
    var liveMusic: Bool?
    var menuForChildren: Bool?
    var servesDessert: Bool?
    var servesCoffee: Bool?
    var goodForChildren: Bool?
    var goodForGroups: Bool?
    var allowsDogs: Bool?
    var restroom: Bool?
    var paymentOptions: PlaceDetails.PaymentOptions?
    var generativeSummary: String?
    var isFree: Bool?
    
    // Coding keys to match the API response
    private enum CodingKeys: String, CodingKey {
        case id
        case emoji
        case location
        // Note: other fields are not included in CodingKeys since they're not in the initial API response
    }
    
    // Nested Location structure
    struct Location: Codable, Equatable {
        var latitude: Double
        var longitude: Double
    }
    
    // Computed property to get CLLocationCoordinate2D for MapKit
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    // Implement Equatable to compare places by ID
    static func == (lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Update place with details from the details API response
    mutating func updateWithDetails(_ details: PlaceDetails) {
        self.displayName = details.displayName
        self.rating = details.rating
        self.reviews = details.reviews
        self.priceLevel = details.priceLevel
        self.userRatingCount = details.userRatingCount
        self.openNow = details.openNow
        self.primaryTypeDisplayName = details.primaryTypeDisplayName
        self.takeout = details.takeout
        self.delivery = details.delivery
        self.dineIn = details.dineIn
        self.editorialSummary = details.editorialSummary
        self.outdoorSeating = details.outdoorSeating
        self.liveMusic = details.liveMusic
        self.menuForChildren = details.menuForChildren
        self.servesDessert = details.servesDessert
        self.servesCoffee = details.servesCoffee
        self.goodForChildren = details.goodForChildren
        self.goodForGroups = details.goodForGroups
        self.allowsDogs = details.allowsDogs
        self.restroom = details.restroom
        self.paymentOptions = details.paymentOptions
        self.generativeSummary = details.generativeSummary
        self.isFree = details.isFree
    }
}

// Extension to make Place usable as a map annotation
extension Place {
    @MainActor
    func mapAnnotation(onTap: @escaping (Place) -> Void, isHighlighted: Bool = false) -> some MapContent {
        Annotation(coordinate: coordinate) {
            // Check if this place is favorited
            let isFavorited = ServiceContainer.shared.userPreferences.isFavorite(placeId: id)
            
            // Get user rating if available
            let userRating = ServiceContainer.shared.userPreferences.getRating(placeId: id)
            
            // Use the new PlaceAnnotation view
            PlaceAnnotation(
                emoji: emoji,
                isFavorite: isFavorited,
                userRating: userRating,
                isLoading: false,
                isHighlighted: isHighlighted,
                onTap: { onTap(self) }
            )
        } label: {
           // No-op (only showing Emojis)
        }
    }
} 
