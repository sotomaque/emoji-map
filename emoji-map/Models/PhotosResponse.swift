//
//  PhotosResponse.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation

// Response structure for the photos API
struct PhotosResponse: Codable {
    let data: [String]
    let cacheHit: Bool
    let count: Int
} 