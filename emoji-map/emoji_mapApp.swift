//
//  emoji_mapApp.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI

// Service container to hold shared service instances
class ServiceContainer {
    static let shared = ServiceContainer()
    
    let userPreferences = UserPreferences()
    let googlePlacesService = GooglePlacesService()
    
    private init() {} // Singleton
}

@main
struct emoji_mapApp: App {
    // Use the shared service container
    private let serviceContainer = ServiceContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MapViewModel(
                    googlePlacesService: serviceContainer.googlePlacesService,
                    userPreferences: serviceContainer.userPreferences
                ))
        }
    }
}
