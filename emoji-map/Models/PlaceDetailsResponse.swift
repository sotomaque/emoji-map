//
//  PlaceDetailsResponse.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation

// Response structure for the place details API
struct PlaceDetailsResponse: Codable {
    let data: PlaceDetails
    let cacheHit: Bool
    let count: Int
}

// Structure for place details
struct PlaceDetails: Codable {
    let name: String
    let reviews: [Review]?
    let rating: Double?
    let priceLevel: String?
    let userRatingCount: Int?
    let openNow: Bool?
    let displayName: String?
    let primaryTypeDisplayName: String?
    let takeout: Bool?
    let delivery: Bool?
    let dineIn: Bool?
    let editorialSummary: String?
    let outdoorSeating: Bool?
    let liveMusic: Bool?
    let menuForChildren: Bool?
    let servesDessert: Bool?
    let servesCoffee: Bool?
    let goodForChildren: Bool?
    let goodForGroups: Bool?
    let allowsDogs: Bool?
    let restroom: Bool?
    let paymentOptions: PaymentOptions?
    let generativeSummary: String?
    let isFree: Bool?
    
    // Review structure
    struct Review: Codable, Identifiable {
        let name: String
        let relativePublishTimeDescription: String
        let rating: Int
        let text: TextContent
        let originalText: TextContent
        
        // Use the name as the ID
        var id: String { name }
        
        // Text content structure
        struct TextContent: Codable {
            let text: String
            let languageCode: String
        }
    }
    
    // Payment options structure
    struct PaymentOptions: Codable {
        let acceptsCreditCards: Bool?
        let acceptsDebitCards: Bool?
        let acceptsCashOnly: Bool?
    }
} 