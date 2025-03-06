//
//  emoji_mapApp.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI


@main
struct emoji_mapApp: App {
    // Use the shared service container
    private let serviceContainer = ServiceContainer.shared
    
    // Create a state object to track onboarding status
    @StateObject private var userPreferences = ServiceContainer.shared.userPreferences
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if userPreferences.hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(MapViewModel(
                            googlePlacesService: serviceContainer.googlePlacesService,
                            userPreferences: serviceContainer.userPreferences
                        ))
                } else {
                    OnboardingView(userPreferences: userPreferences, isFromSettings: false)
                }
            }
            .animation(.easeInOut, value: userPreferences.hasCompletedOnboarding)
        }
    }
}
