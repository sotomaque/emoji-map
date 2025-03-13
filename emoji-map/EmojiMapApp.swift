//
//  EmojiMapApp.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import os.log

@main
struct EmojiMapApp: App {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "emoji_mapApp")
    
    // Add state to track if splash screen is showing
    @State private var isShowingSplash = false
    // Add state to track content opacity
    @State private var contentOpacity: Double = 0
    
    // Initialize services from the container
    @StateObject private var userPreferences = {
        MainActor.assumeIsolated {
            ServiceContainer.shared.userPreferences
        }
    }()
    
    init() {
        // Print network interfaces if using development server
        if Configuration.IS_DEV_SERVER {
            logger.notice("Development server mode is enabled")
            Configuration.printNetworkInterfaces()
        }
        
        // Log app initialization
        logger.notice("EmojiMapApp initializing with ServiceContainer")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Show content based on onboarding status
                Group {
                    if userPreferences.hasCompletedOnboarding {
                        Home()
                            .opacity(contentOpacity)
                            .animation(.easeIn(duration: 0.5), value: contentOpacity)
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
                    // Start with content hidden if splash is showing
                    contentOpacity = isShowingSplash ? 0 : 1
                }
                
                // Show splash screen on top if it's active
                if isShowingSplash {
                    SplashScreen {
                        // This closure is called when the splash screen animation completes
                        withAnimation(.easeOut(duration: 0.5)) {
                            isShowingSplash = false
                            // Fade in the content as splash fades out
                            contentOpacity = 1
                        }
                    }
                    .zIndex(1) // Ensure splash screen is on top
                    .transition(.opacity) // This makes it fade out when removed
                }
            }
        }
    }
}


