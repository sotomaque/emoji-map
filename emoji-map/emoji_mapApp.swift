//
//  emoji_mapApp.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI

@main
struct emoji_mapApp: App {
    // Use the shared service container - safely accessed on the main thread
    private var serviceContainer: ServiceContainer {
        MainActor.assumeIsolated {
            ServiceContainer.shared
        }
    }
    
    // Create a state object to track onboarding status - safely accessed on the main thread
    @StateObject private var userPreferences = {
        MainActor.assumeIsolated {
            ServiceContainer.shared.userPreferences
        }
    }()
    
    // Add state to track if splash screen is showing
    @State private var isShowingSplash = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Show content based on onboarding status
                Group {
                    if userPreferences.hasCompletedOnboarding {
                        ContentView()
                    } else {
                        OnboardingView(userPreferences: userPreferences, isFromSettings: false)
                    }
                }
                .animation(.easeInOut, value: userPreferences.hasCompletedOnboarding)
                .zIndex(0)
                .onAppear {
                    // Only show splash screen on subsequent launches (not first launch)
                    // This means the app has been launched before AND onboarding is completed
                    isShowingSplash = userPreferences.hasLaunchedBefore && userPreferences.hasCompletedOnboarding
                }
                
                // Show splash screen on top if it's active
                if isShowingSplash {
                    SplashScreen {
                        // This closure is called when the splash screen animation completes
                        withAnimation(.easeOut(duration: 0.5)) {
                            isShowingSplash = false
                        }
                    }
                    .zIndex(1) // Ensure splash screen is on top
                    .transition(.opacity) // This makes it fade out when removed
                }
            }
        }
    }
}
