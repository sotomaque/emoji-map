//
//  configuration.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import Foundation

enum ConfigurationError: Error {
    case missingConfigFile
    case invalidConfigFormat
    case missingAPIKey
    
    var localizedDescription: String {
        switch self {
        case .missingConfigFile:
            return "Configuration file (config.plist) not found."
        case .invalidConfigFormat:
            return "Configuration file format is invalid."
        case .missingAPIKey:
            return "Google Places API key is missing from configuration."
        }
    }
}

struct Configuration {
    // Default mock API key for development/testing when real key is unavailable
    private static let mockAPIKey = "MOCK_API_KEY_FOR_DEVELOPMENT"
    
    // Flag to indicate if we're using a mock key
    private(set) static var isUsingMockKey = false
    
    // Flag to indicate if configuration has errors
    private(set) static var configurationError: ConfigurationError?
    
    // Get the Google Places API key with fallback to mock key
    static var googlePlacesAPIKey: String {
        do {
            return try fetchGooglePlacesAPIKey()
        } catch let error as ConfigurationError {
            configurationError = error
            isUsingMockKey = true
            print("Configuration error: \(error.localizedDescription). Using mock API key for development.")
            return mockAPIKey
        } catch {
            configurationError = .invalidConfigFormat
            isUsingMockKey = true
            print("Unknown configuration error. Using mock API key for development.")
            return mockAPIKey
        }
    }
    
    // Attempt to fetch the real API key
    private static func fetchGooglePlacesAPIKey() throws -> String {
        guard let path = Bundle.main.path(forResource: "config", ofType: "plist") else {
            throw ConfigurationError.missingConfigFile
        }
        
        guard let dict = NSDictionary(contentsOfFile: path) else {
            throw ConfigurationError.invalidConfigFormat
        }
        
        guard let key = dict["GooglePlacesAPIKey"] as? String, !key.isEmpty else {
            throw ConfigurationError.missingAPIKey
        }
        
        return key
    }
    
    // Check if the configuration is valid
    static var isConfigurationValid: Bool {
        return configurationError == nil && !isUsingMockKey
    }
    
    // Get a user-friendly error message if configuration is invalid
    static var configurationErrorMessage: String? {
        return configurationError?.localizedDescription
    }
}
