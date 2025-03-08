import Foundation
import os.log

/// Manages request throttling to prevent too frequent API calls
class RequestThrottler {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "RequestThrottler")
    
    // Track the last request time to prevent too frequent requests
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval
    
    // Track if a request is in progress
    private var isRequestInProgress = false
    
    // Lock for thread safety
    private let lock = NSLock()
    
    /// Initialize with a minimum request interval
    /// - Parameter minimumInterval: Minimum time between requests in seconds
    init(minimumInterval: TimeInterval = 2.0) {
        self.minimumRequestInterval = minimumInterval
    }
    
    /// Check if a request can be made now
    /// - Returns: True if a request can be made, false if it should be throttled
    func canMakeRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if a request is already in progress
        if isRequestInProgress {
            logger.notice("Request already in progress, throttling")
            return false
        }
        
        // Check if we're making requests too frequently
        let now = Date()
        if now.timeIntervalSince(lastRequestTime) < minimumRequestInterval {
            logger.notice("Request throttled - too many requests in a short time")
            return false
        }
        
        return true
    }
    
    /// Mark that a request is starting
    func requestStarting() {
        lock.lock()
        defer { lock.unlock() }
        
        lastRequestTime = Date()
        isRequestInProgress = true
        
        logger.debug("Request starting, updated last request time")
    }
    
    /// Mark that a request has completed
    func requestCompleted() {
        lock.lock()
        defer { lock.unlock() }
        
        isRequestInProgress = false
        
        logger.debug("Request completed")
    }
    
    /// Reset the throttler to allow immediate requests
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        lastRequestTime = Date.distantPast
        isRequestInProgress = false
        
        logger.debug("Throttler reset")
    }
} 