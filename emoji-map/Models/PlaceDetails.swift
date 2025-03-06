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
    let relativeTimeDescription: String = "Recently"
    
    // Convenience initializer to create from tuple
    init(from tuple: (author: String, text: String, rating: Int)) {
        self.authorName = tuple.author
        self.text = tuple.text
        self.rating = tuple.rating
    }
    
    // Custom initializer
    init(authorName: String, text: String, rating: Int) {
        self.authorName = authorName
        self.text = text
        self.rating = rating
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
    let reviews: [(author: String, text: String, rating: Int)]
    
    // Standard initializer
    init(photos: [String], reviews: [(author: String, text: String, rating: Int)]) {
        self.photos = photos
        self.reviews = reviews
    }
    
    // Computed property to get reviews as Review objects
    var reviewObjects: [Review] {
        return reviews.map { Review(from: $0) }
    }
    
    // Custom coding keys for encoding/decoding
    enum CodingKeys: String, CodingKey {
        case photos, reviews
    }
    
    // Custom encoding for tuple array
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photos, forKey: .photos)
        
        // Convert tuples to a codable format
        let codableReviews = reviews.map { 
            ["author": $0.author, "text": $0.text, "rating": String($0.rating)]
        }
        try container.encode(codableReviews, forKey: .reviews)
    }
    
    // Custom decoding for tuple array
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        photos = try container.decode([String].self, forKey: .photos)
        
        // Convert from codable format back to tuples
        let codableReviews = try container.decode([[String: String]].self, forKey: .reviews)
        reviews = codableReviews.compactMap { dict in
            guard let author = dict["author"],
                  let text = dict["text"],
                  let ratingString = dict["rating"],
                  let rating = Int(ratingString) else {
                return nil
            }
            return (author, text, rating)
        }
    }
}
