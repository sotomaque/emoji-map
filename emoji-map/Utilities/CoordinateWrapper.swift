//
//  CoordinateWrapper.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//


import CoreLocation

struct CoordinateWrapper: Equatable {
    let coordinate: CLLocationCoordinate2D
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
    
    static func == (lhs: CoordinateWrapper, rhs: CoordinateWrapper) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
