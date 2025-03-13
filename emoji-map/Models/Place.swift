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

// Main response structure from the API
struct PlacesResponse: Codable {
    let data: [Place]
    let count: Int
    let cacheHit: Bool
}

// Place model representing a location with an emoji
struct Place: Identifiable, Codable, Equatable {
    var id: String
    var emoji: String
    var location: Location
    
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
}

// Extension to make Place usable as a map annotation
extension Place {
    func mapAnnotation(onTap: @escaping (Place) -> Void) -> some MapContent {
        Annotation(coordinate: coordinate) {
            Text(emoji)
                .font(.system(size: 30))
                .onTapGesture {
                    onTap(self)
                }
        } label: {
           // No-op (only showing Emojis)
        }
    }
} 
