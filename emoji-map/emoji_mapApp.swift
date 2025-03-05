//
//  emoji_mapApp.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI

@main
struct emoji_mapApp: App {
    // Create shared instances of services
    private let userPreferences = UserPreferences()
    private let googlePlacesService = GooglePlacesService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MapViewModel(
                    googlePlacesService: googlePlacesService,
                    userPreferences: userPreferences
                ))
        }
    }
}
