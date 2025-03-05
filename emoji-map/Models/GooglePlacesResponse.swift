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
    let reviews: [Review]?
}

struct Photo: Decodable {
    let photo_reference: String
}

struct Review: Decodable {
    let author_name: String
    let text: String
    let rating: Int
}
