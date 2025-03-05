//
//  configuration.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import Foundation

struct Configuration {
    static var googlePlacesAPIKey: String {
        guard let path = Bundle.main.path(forResource: "config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GooglePlacesAPIKey"] as? String else {
            fatalError("Google Places API key not found in Config.plist")
        }
        return key
    }
}
