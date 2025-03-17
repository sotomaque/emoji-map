//
//  PlacesResponse.swift
//  emoji-map
//
//  Created by Enrique on 3/14/25.
//

import Foundation

// Main response structure from the API
struct PlacesResponse: Codable {
    let results: [Place]
    let count: Int
    let cacheHit: Bool
}
