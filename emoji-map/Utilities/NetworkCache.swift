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
    
    // Private initializer for singleton
    private init() {
        // Set cache limits
        cache.countLimit = 100 // Maximum number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB limit
        
        // Register for memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Log cache initialization (keep this for production)
        logger.info("NetworkCache initialized with places expiration: \(self.defaultPlacesExpiration)s, details expiration: \(self.defaultDetailsExpiration)s")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Clear the cache when memory warning is received
    @objc func clearCache() {
        logger.info("Clearing cache due to memory warning")
        cache.removeAllObjects()
    }
    
    /// Store data in the cache with a key and expiration time
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    ///   - expirationTime: Time in seconds until the cache entry expires
    func store(_ data: Data, forKey key: String, expirationTime: TimeInterval) {
        let entry = CacheEntry(data: data, expirationTime: Date().addingTimeInterval(expirationTime))
        cache.setObject(entry, forKey: key as NSString)
        logger.debug("Stored data for key: \(key)")
    }
    
    /// Store place details in the cache
    /// - Parameters:
    ///   - details: The place details to cache
    ///   - placeId: The place ID to use as the key
    func storePlaceDetails(_ details: PlaceDetails, forPlaceId placeId: String) {
        guard let data = try? JSONEncoder().encode(details) else {
            logger.error("Failed to encode place details for caching")
            return
        }
        
        let key = "placeDetails_\(placeId)"
        store(data, forKey: key, expirationTime: defaultDetailsExpiration)
        logger.info("Cached details for place ID: \(placeId)")
    }
    
    /// Store places in the cache
    /// - Parameters:
    ///   - places: The places to cache
    ///   - cacheKey: The cache key (usually based on search parameters)
    func storePlaces(_ places: [Place], forKey cacheKey: String) {
        guard let data = try? JSONEncoder().encode(places) else {
            logger.error("Failed to encode places for caching")
            return
        }
        
        store(data, forKey: cacheKey, expirationTime: defaultPlacesExpiration)
        logger.info("Cached \(places.count) places")
    }
    
    /// Retrieve data from the cache if it exists and hasn't expired
    /// - Parameter key: The cache key
    /// - Returns: The cached data, or nil if not found or expired
    func retrieveData(forKey key: String) -> Data? {
        guard let entry = cache.object(forKey: key as NSString) else {
            logger.debug("Cache miss for key: \(key)")
            return nil
        }
        
        // Check if the entry has expired
        if Date() > entry.expirationTime {
            logger.debug("Cache entry expired for key: \(key)")
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        
        logger.debug("Cache hit for key: \(key)")
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
    ///   - categories: The categories to search for
    ///   - showOpenNowOnly: Whether to show only open places
    /// - Returns: A unique cache key
    func generatePlacesCacheKey(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)], showOpenNowOnly: Bool) -> String {
        // Round coordinates to reduce cache fragmentation (within ~100m)
        let roundedLat = round(center.latitude * 100) / 100
        let roundedLng = round(center.longitude * 100) / 100
        
        // Sort categories to ensure consistent keys
        let sortedCategories = categories.sorted { $0.type < $1.type }
        let categoriesString = sortedCategories.map { "\($0.type)" }.joined(separator: ",")
        
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
