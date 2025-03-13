//
//  PlaceDetails.swift
//  emoji-map
//
//  Created by Enrique on 3/4/25.
//

import Foundation

/// Review model for use in the UI.
/// This is separate from APIReview (in GooglePlacesResponse.swift) which is used for decoding API responses.
/// The GooglePlacesService converts APIReview objects to tuples, which are then used to create Review objects.
struct Review: Identifiable, Codable {
    let id = UUID()
    let authorName: String
    let text: String
    let rating: Int
    let relativeTimeDescription: String
    
    // Convenience initializer to create from tuple
    init(from tuple: (author: String, text: String, rating: Int)) {
        self.authorName = tuple.author
        self.text = tuple.text
        self.rating = tuple.rating
        self.relativeTimeDescription = "Recently" // Default value
    }
    
    // Custom initializer
    init(authorName: String, text: String, rating: Int, relativeTimeDescription: String = "Recently") {
        self.authorName = authorName
        self.text = text
        self.rating = rating
        self.relativeTimeDescription = relativeTimeDescription
    }
    
    // Static method to convert from APIReview
    static func fromAPIReview(_ apiReview: APIReview) -> Review {
        return Review(
            authorName: apiReview.author_name,
            text: apiReview.text,
            rating: apiReview.rating
        )
    }
    
    // Custom encoding for UUID
    enum CodingKeys: String, CodingKey {
        case authorName, text, rating, relativeTimeDescription
    }
}

struct PlaceDetails: Codable {
    let photos: [String] // URLs to photos
    let reviews: [(author: String, text: String, rating: Int, relativeTime: String)]
    
    // Additional fields from the new API response
    let name: String?
    let rating: Double?
    let priceLevel: Int?
    let userRatingCount: Int?
    let openNow: Bool?
    let primaryTypeDisplayName: String?
    let generativeSummary: String?
    
    // Amenities
    let takeout: Bool?
    let delivery: Bool?
    let dineIn: Bool?
    let outdoorSeating: Bool?
    let liveMusic: Bool?
    let menuForChildren: Bool?
    let servesDessert: Bool?
    let servesCoffee: Bool?
    let goodForChildren: Bool?
    let goodForGroups: Bool?
    let allowsDogs: Bool?
    let restroom: Bool?
    
    // Payment options
    let acceptsCreditCards: Bool?
    let acceptsDebitCards: Bool?
    let acceptsCashOnly: Bool?
    
    // Standard initializer
    init(
        photos: [String],
        reviews: [(author: String, text: String, rating: Int, relativeTime: String)],
        name: String? = nil,
        rating: Double? = nil,
        priceLevel: Int? = nil,
        userRatingCount: Int? = nil,
        openNow: Bool? = nil,
        primaryTypeDisplayName: String? = nil,
        generativeSummary: String? = nil,
        takeout: Bool? = nil,
        delivery: Bool? = nil,
        dineIn: Bool? = nil,
        outdoorSeating: Bool? = nil,
        liveMusic: Bool? = nil,
        menuForChildren: Bool? = nil,
        servesDessert: Bool? = nil,
        servesCoffee: Bool? = nil,
        goodForChildren: Bool? = nil,
        goodForGroups: Bool? = nil,
        allowsDogs: Bool? = nil,
        restroom: Bool? = nil,
        acceptsCreditCards: Bool? = nil,
        acceptsDebitCards: Bool? = nil,
        acceptsCashOnly: Bool? = nil
    ) {
        self.photos = photos
        self.reviews = reviews
        self.name = name
        self.rating = rating
        self.priceLevel = priceLevel
        self.userRatingCount = userRatingCount
        self.openNow = openNow
        self.primaryTypeDisplayName = primaryTypeDisplayName
        self.generativeSummary = generativeSummary
        self.takeout = takeout
        self.delivery = delivery
        self.dineIn = dineIn
        self.outdoorSeating = outdoorSeating
        self.liveMusic = liveMusic
        self.menuForChildren = menuForChildren
        self.servesDessert = servesDessert
        self.servesCoffee = servesCoffee
        self.goodForChildren = goodForChildren
        self.goodForGroups = goodForGroups
        self.allowsDogs = allowsDogs
        self.restroom = restroom
        self.acceptsCreditCards = acceptsCreditCards
        self.acceptsDebitCards = acceptsDebitCards
        self.acceptsCashOnly = acceptsCashOnly
    }
    
    // Computed property to get reviews as Review objects
    var reviewObjects: [Review] {
        return reviews.map { Review(authorName: $0.author, text: $0.text, rating: $0.rating, relativeTimeDescription: $0.relativeTime) }
    }
    
    // Custom coding keys for encoding/decoding
    enum CodingKeys: String, CodingKey {
        case photos, reviews
        case name, rating, priceLevel, userRatingCount, openNow, primaryTypeDisplayName, generativeSummary
        case takeout, delivery, dineIn, outdoorSeating, liveMusic, menuForChildren, servesDessert, servesCoffee
        case goodForChildren, goodForGroups, allowsDogs, restroom
        case acceptsCreditCards, acceptsDebitCards, acceptsCashOnly
    }
    
    // Custom encoding for tuple array
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photos, forKey: .photos)
        
        // Convert tuples to a codable format
        let codableReviews = reviews.map { 
            ["author": $0.author, "text": $0.text, "rating": String($0.rating), "relativeTime": $0.relativeTime]
        }
        try container.encode(codableReviews, forKey: .reviews)
        
        // Encode additional fields
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(priceLevel, forKey: .priceLevel)
        try container.encodeIfPresent(userRatingCount, forKey: .userRatingCount)
        try container.encodeIfPresent(openNow, forKey: .openNow)
        try container.encodeIfPresent(primaryTypeDisplayName, forKey: .primaryTypeDisplayName)
        try container.encodeIfPresent(generativeSummary, forKey: .generativeSummary)
        
        // Encode amenities
        try container.encodeIfPresent(takeout, forKey: .takeout)
        try container.encodeIfPresent(delivery, forKey: .delivery)
        try container.encodeIfPresent(dineIn, forKey: .dineIn)
        try container.encodeIfPresent(outdoorSeating, forKey: .outdoorSeating)
        try container.encodeIfPresent(liveMusic, forKey: .liveMusic)
        try container.encodeIfPresent(menuForChildren, forKey: .menuForChildren)
        try container.encodeIfPresent(servesDessert, forKey: .servesDessert)
        try container.encodeIfPresent(servesCoffee, forKey: .servesCoffee)
        try container.encodeIfPresent(goodForChildren, forKey: .goodForChildren)
        try container.encodeIfPresent(goodForGroups, forKey: .goodForGroups)
        try container.encodeIfPresent(allowsDogs, forKey: .allowsDogs)
        try container.encodeIfPresent(restroom, forKey: .restroom)
        
        // Encode payment options
        try container.encodeIfPresent(acceptsCreditCards, forKey: .acceptsCreditCards)
        try container.encodeIfPresent(acceptsDebitCards, forKey: .acceptsDebitCards)
        try container.encodeIfPresent(acceptsCashOnly, forKey: .acceptsCashOnly)
    }
    
    // Custom decoding for tuple array
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        photos = try container.decode([String].self, forKey: .photos)
        
        // First try to decode as array of dictionaries with string values (original format)
        do {
            let codableReviews = try container.decode([[String: String]].self, forKey: .reviews)
            reviews = codableReviews.compactMap { dict in
                guard let author = dict["author"],
                      let text = dict["text"],
                      let ratingString = dict["rating"],
                      let rating = Int(ratingString) else {
                    return nil
                }
                let relativeTime = dict["relativeTime"] ?? "Recently"
                return (author, text, rating, relativeTime)
            }
        } catch {
            // If that fails, try to decode as array of objects with typed values (web backend format)
            struct WebReview: Codable {
                let author: String
                let text: String
                let rating: Int
                let relativeTime: String?
            }
            
            let webReviews = try container.decode([WebReview].self, forKey: .reviews)
            reviews = webReviews.map { review in
                return (review.author, review.text, review.rating, review.relativeTime ?? "Recently")
            }
        }
        
        // Decode additional fields
        name = try container.decodeIfPresent(String.self, forKey: .name)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        userRatingCount = try container.decodeIfPresent(Int.self, forKey: .userRatingCount)
        openNow = try container.decodeIfPresent(Bool.self, forKey: .openNow)
        primaryTypeDisplayName = try container.decodeIfPresent(String.self, forKey: .primaryTypeDisplayName)
        generativeSummary = try container.decodeIfPresent(String.self, forKey: .generativeSummary)
        
        // Decode amenities
        takeout = try container.decodeIfPresent(Bool.self, forKey: .takeout)
        delivery = try container.decodeIfPresent(Bool.self, forKey: .delivery)
        dineIn = try container.decodeIfPresent(Bool.self, forKey: .dineIn)
        outdoorSeating = try container.decodeIfPresent(Bool.self, forKey: .outdoorSeating)
        liveMusic = try container.decodeIfPresent(Bool.self, forKey: .liveMusic)
        menuForChildren = try container.decodeIfPresent(Bool.self, forKey: .menuForChildren)
        servesDessert = try container.decodeIfPresent(Bool.self, forKey: .servesDessert)
        servesCoffee = try container.decodeIfPresent(Bool.self, forKey: .servesCoffee)
        goodForChildren = try container.decodeIfPresent(Bool.self, forKey: .goodForChildren)
        goodForGroups = try container.decodeIfPresent(Bool.self, forKey: .goodForGroups)
        allowsDogs = try container.decodeIfPresent(Bool.self, forKey: .allowsDogs)
        restroom = try container.decodeIfPresent(Bool.self, forKey: .restroom)
        
        // Decode payment options
        acceptsCreditCards = try container.decodeIfPresent(Bool.self, forKey: .acceptsCreditCards)
        acceptsDebitCards = try container.decodeIfPresent(Bool.self, forKey: .acceptsDebitCards)
        acceptsCashOnly = try container.decodeIfPresent(Bool.self, forKey: .acceptsCashOnly)
    }
}
