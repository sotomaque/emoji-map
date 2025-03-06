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
        // Log all environment variables for debugging
        logger.debug("🔍 DEBUG: Checking for API key...")
        
        // Print all environment variables to help debug
        let allEnvVars = ProcessInfo.processInfo.environment
        logger.debug("🔍 DEBUG: Environment variables count: \(allEnvVars.count)")
        
        // Check specifically for our key
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
            let allKeys = allEnvVars.keys.joined(separator: ", ")
            logger.debug("🔍 DEBUG: Available environment variables: \(allKeys)")
        }
        
        // Then try to get from keychain (for production)
        if let key = KeychainHelper.get(service: "com.emoji-map", account: "GooglePlacesAPIKey") {
            if !key.isEmpty {
                logger.notice("✅ SUCCESS: Using API key from keychain")
                return key
            } else {
                logger.error("❌ ERROR: API key found in keychain but is empty")
            }
        } else {
            logger.error("❌ ERROR: No API key found in keychain")
        }
        
        // Check if .env file exists in the bundle
        if let envURL = Bundle.main.url(forResource: ".env", withExtension: nil) {
            logger.debug("🔍 DEBUG: .env file found at path: \(envURL.path)")
            
            do {
                let contents = try String(contentsOf: envURL, encoding: .utf8)
                logger.debug("🔍 DEBUG: .env file contents: \(contents)")
                
                // Try to parse the .env file manually
                let lines = contents.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine.hasPrefix("GOOGLE_PLACES_API_KEY=") {
                        let key = trimmedLine.dropFirst("GOOGLE_PLACES_API_KEY=".count)
                        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanKey.isEmpty {
                            logger.notice("✅ SUCCESS: Found API key in .env file: \(cleanKey.prefix(4))...")
                            
                            // Store in keychain for future use
                            storeAPIKey(String(cleanKey), named: "GooglePlacesAPIKey")
                            
                            return String(cleanKey)
                        }
                    }
                }
                
                logger.error("❌ ERROR: GOOGLE_PLACES_API_KEY not found in .env file contents")
            } catch {
                logger.error("❌ ERROR: Failed to read .env file: \(error.localizedDescription)")
            }
        } else {
            logger.error("❌ ERROR: .env file not found in bundle")
            
            // Check if we're running in a CI environment
            if ProcessInfo.processInfo.environment["CI"] != nil || 
               ProcessInfo.processInfo.environment["CI_XCODE_CLOUD"] != nil {
                logger.notice("ℹ️ INFO: Running in CI environment, mock mode is expected")
            }
            
            // List all bundle resources to help debug
            if let resourcePaths = Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil) as [String]? {
                let resourceNames = resourcePaths.map { URL(fileURLWithPath: $0).lastPathComponent }
                logger.debug("🔍 DEBUG: Bundle resources: \(resourceNames.joined(separator: ", "))")
            }
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
    
    /// Store an API key in the keychain
    /// - Parameters:
    ///   - key: The API key to store
    ///   - keyName: The name of the key
    static func storeAPIKey(_ key: String, named keyName: String) {
        guard !key.isEmpty else {
            logger.error("❌ ERROR: Attempted to store empty API key")
            return
        }
        
        do {
            try KeychainHelper.set(key, service: "com.emoji-map", account: keyName)
            logger.notice("✅ SUCCESS: Stored API key in keychain: \(keyName)")
        } catch {
            logger.error("❌ ERROR: Failed to store API key in keychain: \(error.localizedDescription)")
        }
    }
    
    /// Check if an API key is stored in the keychain
    /// - Parameter keyName: The name of the key to check
    /// - Returns: True if the key exists in the keychain, false otherwise
    static func hasStoredAPIKey(_ keyName: String) -> Bool {
        return KeychainHelper.get(service: "com.emoji-map", account: keyName) != nil
    }
    
    /// Delete an API key from the keychain
    /// - Parameter keyName: The name of the key to delete
    static func deleteAPIKey(named keyName: String) {
        do {
            try KeychainHelper.delete(service: "com.emoji-map", account: keyName)
            logger.notice("✅ SUCCESS: Deleted API key from keychain: \(keyName)")
        } catch {
            logger.error("❌ ERROR: Failed to delete API key from keychain: \(error.localizedDescription)")
        }
    }
}

/// Helper class for keychain operations
class KeychainHelper {
    /// Store a string in the keychain
    /// - Parameters:
    ///   - value: The string to store
    ///   - service: The service identifier
    ///   - account: The account identifier
    static func set(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        
        // Create query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Add access control for better security
        #if !targetEnvironment(simulator)
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil
        )
        query[kSecAttrAccessControl as String] = access
        #endif
        
        // Check if item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            // Item exists, update it
            let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
            
        case errSecItemNotFound:
            // Item doesn't exist, add it
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
            
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Retrieve a string from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: The stored string, or nil if not found
    static func get(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Delete a keychain item
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Errors that can occur during keychain operations
    enum KeychainError: Error {
        case encodingError
        case unhandledError(status: OSStatus)
    }
}
