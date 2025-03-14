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
    
    // MARK: - Development Configuration
    
    /// Toggle to use local development server
    /// Set this to true to use localhost:3000 instead of production URL
    static let IS_DEV_SERVER = false
    
    /// The IP address of your development machine
    /// Change this to your computer's local IP address (e.g., "192.168.1.100")
    /// You can find your IP address by running `ipconfig getifaddr en0` in Terminal
    static let DEV_SERVER_IP = "192.168.1.240"
    
    /// The port your development server is running on
    static let DEV_SERVER_PORT = "3000"
    
    // MARK: - Backend Configuration
    
    /// The URL for the backend API
    static var backendURL: URL {
        // Check if we have a custom backend URL from environment
        if let customURL = ProcessInfo.processInfo.environment["BACKEND_URL"],
           let url = URL(string: customURL) {
            logger.notice("Using custom backend URL from environment: \(customURL)")
            return url
        }
        
        // Use development server if IS_DEV_SERVER is true
        if IS_DEV_SERVER {
            let devServerURL = "http://\(DEV_SERVER_IP):\(DEV_SERVER_PORT)"
            logger.notice("Using development backend URL: \(devServerURL)")
            return URL(string: devServerURL)!
        }
        
        // Otherwise use production URL
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
    
    // MARK: - Development Utilities
    
    /// Prints information to help developers connect to their local development server
    /// Call this function from your app's initialization code when IS_DEV_SERVER is true
    static func printNetworkInterfaces() {
        #if DEBUG
        logger.notice("Development server mode is ENABLED")
        logger.notice("To use your local development server:")
        logger.notice("1. Make sure your Next.js server is running on your computer (npm run dev)")
        logger.notice("2. Find your computer's IP address (run 'ipconfig getifaddr en0' in Terminal)")
        logger.notice("3. Update DEV_SERVER_IP in Configuration.swift with your IP address")
        logger.notice("4. Ensure your iOS device/simulator and computer are on the same network")
        logger.notice("Current development server URL: http://\(DEV_SERVER_IP):\(DEV_SERVER_PORT)")
        #endif
    }
}
