//
//  NetworkCache.swift
//  emoji-map
//
//  Created by Enrique on 3/9/25.
//

import Foundation
import os.log
import CoreLocation
import UIKit

/// A class for caching network responses with expiration times
class NetworkCache {
    // Singleton instance
    static let shared = NetworkCache()
    
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "NetworkCache")
    
    // Cache storage
    private let cache = NSCache<NSString, CacheEntry>()
    
    // Default expiration times
    private let defaultPlacesExpiration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let defaultDetailsExpiration: TimeInterval = 60 * 60 // 1 hour
    
    // Current expiration times (can be modified through settings)
    private(set) var placesExpiration: TimeInterval
    private(set) var detailsExpiration: TimeInterval
    
    // Cache statistics
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    private(set) var totalCacheEntries: Int = 0
    
    // Cache control
    private(set) var isCachingEnabled: Bool = true
    
    // UserDefaults keys
    private let cachingEnabledKey = "network_cache_enabled"
    private let placesExpirationKey = "places_cache_expiration"
    private let detailsExpirationKey = "details_cache_expiration"
    
    // Private initializer for singleton
    private init() {
        // Set cache limits
        cache.countLimit = 100 // Maximum number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB limit
        
        // Load cache settings from UserDefaults
        let userDefaults = UserDefaults.standard
        isCachingEnabled = userDefaults.object(forKey: cachingEnabledKey) as? Bool ?? true
        placesExpiration = userDefaults.object(forKey: placesExpirationKey) as? TimeInterval ?? defaultPlacesExpiration
        detailsExpiration = userDefaults.object(forKey: detailsExpirationKey) as? TimeInterval ?? defaultDetailsExpiration
        
        // Register for memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Clear places cache on initialization to avoid issues with old cache key format
        clearPlacesCache()
        
        // Log cache initialization (keep this for production)
        logger.info("NetworkCache initialized with places expiration: \(self.placesExpiration)s, details expiration: \(self.detailsExpiration)s")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Clear the cache when memory warning is received
    @objc func clearCache() {
        logger.info("Clearing cache due to memory warning")
        cache.removeAllObjects()
        
        // Reset statistics
        cacheHits = 0
        cacheMisses = 0
        totalCacheEntries = 0
        
        logger.info("Cache cleared")
    }
    
    /// Clear only the places cache, keeping place details
    func clearPlacesCache() {
        // Since we can't reliably get all keys from NSCache, we'll clear the entire cache
        // This is a bit heavy-handed but ensures we don't have any issues with old cache keys
        cache.removeAllObjects()
        logger.info("Cache cleared to remove potentially problematic place cache entries")
    }
    
    /// Enable or disable caching
    func setCachingEnabled(_ enabled: Bool) {
        isCachingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: cachingEnabledKey)
        
        // If disabling caching, clear the cache
        if !enabled {
            clearCache()
        }
        
        logger.info("Caching \(enabled ? "enabled" : "disabled")")
    }
    
    /// Set the expiration time for places cache
    func setPlacesExpiration(_ timeInterval: TimeInterval) {
        placesExpiration = timeInterval
        UserDefaults.standard.set(timeInterval, forKey: placesExpirationKey)
        logger.info("Places cache expiration set to \(timeInterval) seconds")
    }
    
    /// Set the expiration time for details cache
    func setDetailsExpiration(_ timeInterval: TimeInterval) {
        detailsExpiration = timeInterval
        UserDefaults.standard.set(timeInterval, forKey: detailsExpirationKey)
        logger.info("Details cache expiration set to \(timeInterval) seconds")
    }
    
    /// Reset cache settings to defaults
    func resetCacheSettings() {
        setCachingEnabled(true)
        setPlacesExpiration(defaultPlacesExpiration)
        setDetailsExpiration(defaultDetailsExpiration)
        clearCache()
        logger.info("Cache settings reset to defaults")
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> (hits: Int, misses: Int, entries: Int, placesExpiration: TimeInterval, detailsExpiration: TimeInterval, enabled: Bool) {
        return (cacheHits, cacheMisses, totalCacheEntries, placesExpiration, detailsExpiration, isCachingEnabled)
    }
    
    /// Get a list of active cache keys (for debugging purposes)
    func getActiveCacheKeys() -> [String] {
        // Since NSCache doesn't provide a way to enumerate keys, we'll return a list of known keys
        // This is a simplified implementation that won't return all keys
        var keys = [String]()
        
        // Add some sample keys for demonstration
        keys.append("Total entries: \(totalCacheEntries)")
        keys.append("Cache hits: \(cacheHits)")
        keys.append("Cache misses: \(cacheMisses)")
        
        if isCachingEnabled {
            keys.append("Caching is enabled")
        } else {
            keys.append("Caching is disabled")
        }
        
        keys.append("Places expiration: \(Int(placesExpiration / (24 * 60 * 60))) days")
        keys.append("Details expiration: \(Int(detailsExpiration / (60 * 60))) hours")
        
        return keys
    }
    
    /// Store data in the cache with a key and expiration time
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    ///   - expirationTime: Time in seconds until the cache entry expires
    func store(_ data: Data, forKey key: String, expirationTime: TimeInterval) {
        // If caching is disabled, don't store anything
        if !isCachingEnabled {
            logger.debug("Cache disabled, skipping storage for key: \(key)")
            return
        }
        
        let entry = CacheEntry(data: data, expirationTime: Date().addingTimeInterval(expirationTime))
        cache.setObject(entry, forKey: key as NSString)
        totalCacheEntries += 1
        logger.debug("Stored data for key: \(key)")
    }
    
    /// Store place details in the cache
    /// - Parameters:
    ///   - details: The place details to cache
    ///   - placeId: The place ID to use as the key
    func storePlaceDetails(_ details: PlaceDetails, forPlaceId placeId: String) {
        // If caching is disabled, don't store anything
        if !isCachingEnabled {
            return
        }
        
        guard let data = try? JSONEncoder().encode(details) else {
            logger.error("Failed to encode place details for caching")
            return
        }
        
        let key = "placeDetails_\(placeId)"
        store(data, forKey: key, expirationTime: detailsExpiration)
        logger.info("Cached details for place ID: \(placeId)")
    }
    
    /// Store places in the cache
    /// - Parameters:
    ///   - places: The places to cache
    ///   - cacheKey: The cache key (usually based on search parameters)
    func storePlaces(_ places: [Place], forKey cacheKey: String) {
        // If caching is disabled, don't store anything
        if !isCachingEnabled {
            return
        }
        
        guard let data = try? JSONEncoder().encode(places) else {
            logger.error("Failed to encode places for caching")
            return
        }
        
        store(data, forKey: cacheKey, expirationTime: placesExpiration)
        logger.info("Cached \(places.count) places")
    }
    
    /// Retrieve data from the cache if it exists and hasn't expired
    /// - Parameter key: The cache key
    /// - Returns: The cached data, or nil if not found or expired
    func retrieveData(forKey key: String) -> Data? {
        // If caching is disabled, always return nil
        if !isCachingEnabled {
            logger.debug("Cache disabled, skipping cache lookup for key: \(key)")
            cacheMisses += 1
            return nil
        }
        
        guard let entry = cache.object(forKey: key as NSString) else {
            logger.debug("Cache miss for key: \(key)")
            cacheMisses += 1
            return nil
        }
        
        // Check if the entry has expired
        if Date() > entry.expirationTime {
            logger.debug("Cache entry expired for key: \(key)")
            cache.removeObject(forKey: key as NSString)
            cacheMisses += 1
            return nil
        }
        
        logger.debug("Cache hit for key: \(key)")
        cacheHits += 1
        return entry.data
    }
    
    /// Retrieve place details from the cache
    /// - Parameter placeId: The place ID
    /// - Returns: The cached place details, or nil if not found or expired
    func retrievePlaceDetails(forPlaceId placeId: String) -> PlaceDetails? {
        let key = "placeDetails_\(placeId)"
        guard let data = retrieveData(forKey: key) else {
            return nil
        }
        
        do {
            let details = try JSONDecoder().decode(PlaceDetails.self, from: data)
            logger.info("Retrieved cached details for place ID: \(placeId)")
            return details
        } catch {
            logger.error("Failed to decode cached place details: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Retrieve places from the cache
    /// - Parameter cacheKey: The cache key
    /// - Returns: The cached places, or nil if not found or expired
    func retrievePlaces(forKey cacheKey: String) -> [Place]? {
        guard let data = retrieveData(forKey: cacheKey) else {
            return nil
        }
        
        do {
            let places = try JSONDecoder().decode([Place].self, from: data)
            logger.info("Retrieved \(places.count) cached places")
            return places
        } catch {
            logger.error("Failed to decode cached places: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Remove a specific entry from the cache
    /// - Parameter key: The cache key to remove
    func removeEntry(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        logger.debug("Removed cache entry for key: \(key)")
    }
    
    /// Generate a cache key for places search based on parameters
    /// - Parameters:
    ///   - center: The center coordinate
    ///   - categories: The emojis to search for
    ///   - showOpenNowOnly: Whether to show only open places
    /// - Returns: A unique cache key
    func generatePlacesCacheKey(center: CLLocationCoordinate2D, categories: [String]?, showOpenNowOnly: Bool) -> String {
        // Round coordinates to reduce cache fragmentation (within ~100m)
        let roundedLat = round(center.latitude * 100) / 100
        let roundedLng = round(center.longitude * 100) / 100
        
        // Sort the categories to ensure consistent keys
        let sortedCategories = (categories ?? []).sorted()
        let categoriesString = sortedCategories.joined(separator: ",")
        
        // Log the generated key for debugging
        logger.debug("Generated cache key: places_\(roundedLat)_\(roundedLng)_\(categoriesString)_\(showOpenNowOnly)")
        
        return "places_\(roundedLat)_\(roundedLng)_\(categoriesString)_\(showOpenNowOnly)"
    }
}

/// Cache entry class to store data with expiration time
class CacheEntry: NSObject {
    let data: Data
    let expirationTime: Date
    
    init(data: Data, expirationTime: Date) {
        self.data = data
        self.expirationTime = expirationTime
        super.init()
    }
} 
