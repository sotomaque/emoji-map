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
        // For production, use the key from the secure storage
        return getAPIKey(named: "GooglePlacesAPIKey") ?? fallbackToMockKey()
    }
    
    /// Flag to determine if we're using a mock key
    static var isUsingMockKey: Bool {
        return _isUsingMockKey
    }
    
    // Private flag to track if we're using a mock key
    private static var _isUsingMockKey = false
    
    // MARK: - Private Methods
    
    /// Get an API key from the keychain
    /// - Parameter keyName: The name of the key to retrieve
    /// - Returns: The API key, or nil if not found
    private static func getAPIKey(named keyName: String) -> String? {
        // First try to get from CustomInfo.plist (primary source)
        if let customInfoPath = Bundle.main.path(forResource: "CustomInfo", ofType: "plist"),
           let customInfoDict = NSDictionary(contentsOfFile: customInfoPath),
           let key = customInfoDict[keyName] as? String, !key.isEmpty {
            logger.info("Using API key from CustomInfo.plist: \(keyName)")
            return key
        }
        
        // Then try to get from Config.plist (secondary source)
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let configDict = NSDictionary(contentsOfFile: configPath),
           let key = configDict[keyName] as? String, !key.isEmpty {
            logger.info("Using API key from Config.plist: \(keyName)")
            return key
        }
        
        // Then try to get from Info.plist as fallback (for backward compatibility)
        if let key = Bundle.main.object(forInfoDictionaryKey: keyName) as? String, !key.isEmpty {
            logger.info("Using API key from Info.plist: \(keyName)")
            return key
        }
        
        // Then try to get from keychain (for production)
        if let key = KeychainHelper.get(service: "com.emoji-map", account: keyName), !key.isEmpty {
            logger.info("Using API key from keychain: \(keyName)")
            return key
        }
        
        return nil
    }
    
    /// Fallback to using a mock key for development
    /// - Returns: A placeholder API key
    private static func fallbackToMockKey() -> String {
        _isUsingMockKey = true
        logger.warning("No API key found, using mock data")
        return "mock_api_key_for_development"
    }
    
    /// Store an API key in the keychain
    /// - Parameters:
    ///   - key: The API key to store
    ///   - keyName: The name of the key
    static func storeAPIKey(_ key: String, named keyName: String) {
        guard !key.isEmpty else {
            logger.error("Attempted to store empty API key")
            return
        }
        
        do {
            try KeychainHelper.set(key, service: "com.emoji-map", account: keyName)
            logger.info("Stored API key in keychain: \(keyName)")
        } catch {
            logger.error("Failed to store API key in keychain: \(error.localizedDescription)")
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
