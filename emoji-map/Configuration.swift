//
//  configuration.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import Foundation
import os.log

/// Configuration class for managing API keys and other settings
struct Configuration {
    // Logger for debugging
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "Configuration")
    
    // MARK: - API Keys
    
    /// Google Places API key
    static var googlePlacesAPIKey: String {
        // HARDCODED API KEY FOR TESTFLIGHT
        let hardcodedKey = "AIzaSyCO3I93iowsiHycyGCHtRnoIG5xCE1hJTU"
        
        // Check if we have a valid hardcoded key
        if !hardcodedKey.contains("YOUR_") && !hardcodedKey.isEmpty {
            logger.notice("✅ SUCCESS: Using hardcoded API key: \(hardcodedKey.prefix(4))...")
            return hardcodedKey
        }
        
        // Log all environment variables for debugging
        logger.debug("🔍 DEBUG: Checking for API key...")
        
        // Check specifically for our key in environment variables (from Xcode scheme)
        if let key = ProcessInfo.processInfo.environment["GOOGLE_PLACES_API_KEY"] {
            if !key.isEmpty {
                logger.notice("✅ SUCCESS: Found API key in environment variables: \(key.prefix(4))...")
                return key
            } else {
                logger.error("❌ ERROR: API key found in environment but is empty")
            }
        } else {
            logger.error("❌ ERROR: GOOGLE_PLACES_API_KEY not found in environment variables")
            
            // List all environment variable keys to help debug
            let allKeys = ProcessInfo.processInfo.environment.keys.joined(separator: ", ")
            logger.debug("🔍 DEBUG: Available environment variables: \(allKeys)")
        }
        
        // Fallback to mock key
        return fallbackToMockKey()
    }
    
    /// Flag to determine if we're using a mock key
    static var isUsingMockKey: Bool {
        return _isUsingMockKey
    }
    
    // Private flag to track if we're using a mock key
    private static var _isUsingMockKey = false
    
    // MARK: - Private Methods
    
    /// Fallback to using a mock key for development
    /// - Returns: A placeholder API key
    private static func fallbackToMockKey() -> String {
        _isUsingMockKey = true
        logger.warning("⚠️ WARNING: No API key found, using mock data")
        return "mock_api_key_for_development"
    }
}
