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
struct Review: Identifiable {
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
}

struct PlaceDetails {
    let photos: [String] // URLs to photos
    let reviews: [(author: String, text: String, rating: Int)]
    
    // Computed property to get reviews as Review objects
    var reviewObjects: [Review] {
        return reviews.map { Review(from: $0) }
    }
}
