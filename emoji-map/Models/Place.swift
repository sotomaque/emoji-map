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
}
