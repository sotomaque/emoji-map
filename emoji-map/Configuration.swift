//
//  configuration.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import Foundation
import os.log

/// Configuration class for managing app settings
struct Configuration {
    // Logger for debugging
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "Configuration")
    
    // MARK: - Backend Configuration
    
    /// The URL for the backend API
    static var backendURL: URL {
        // Check if we have a custom backend URL from environment
        if let customURL = ProcessInfo.processInfo.environment["BACKEND_URL"],
           let url = URL(string: customURL) {
            logger.notice("Using custom backend URL from environment: \(customURL)")
            return url
        }
        
        // Always use production URL regardless of build configuration
        logger.notice("Using production backend URL")
        return URL(string: "https://emoji-map-next.vercel.app")!
    }
    
    // MARK: - App Configuration
    
    /// Default search radius in meters
    static let defaultSearchRadius: Int = 5000
    
    /// Maximum search radius in meters
    static let maxSearchRadius: Int = 50000
    
    /// Minimum search radius in meters
    static let minSearchRadius: Int = 1000
    
    /// Cache expiration time in seconds
    static let cacheExpirationTime: TimeInterval = 3600 // 1 hour
}
