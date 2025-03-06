//
//  GooglePlacesResponse.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//


import Foundation

struct GooglePlacesResponse: Decodable {
    let results: [PlaceResult]
    let status: String?
    let error_message: String?
}

struct PlaceResult: Decodable {
    let place_id: String
    let name: String
    let geometry: Geometry
    let vicinity: String
    let price_level: Int?
    let opening_hours: OpeningHours?
    let rating: Double?
}

struct Geometry: Decodable {
    let location: Location
}

struct Location: Decodable {
    let lat: Double
    let lng: Double
}

struct PlaceDetailsResponse: Decodable {
    let result: PlaceDetailsResult
    let status: String?
    let error_message: String?
}

struct PlaceDetailsResult: Decodable {
    let photos: [Photo]?
    let reviews: [APIReview]?
}

struct Photo: Decodable {
    let photo_reference: String
}

/// Review model used for decoding API responses.
/// This is separate from the Review model (in PlaceDetails.swift) which is used in the UI.
/// APIReview objects are converted to tuples in GooglePlacesService, which are then used to create Review objects.
struct APIReview: Decodable {
    let author_name: String
    let text: String
    let rating: Int
}

struct OpeningHours: Decodable {
    let open_now: Bool?
}
