//
//  LocationManager.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import CoreLocation
import os.log

/// Location Manager to handle location permissions and updates
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "LocationManager")
    
    // Minimum distance (in meters) a device must move before an update event is generated
    private let minimumDistanceFilter: Double = 10.0
    
    // Minimum time interval between location log messages (in seconds)
    private let minimumLogInterval: TimeInterval = 5.0
    
    // Track the last logged location and timestamp
    private var lastLoggedLocation: CLLocation?
    private var lastLogTimestamp: Date = Date.distantPast
    
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    
    // Callback for when location updates
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Set distance filter to reduce update frequency
        locationManager.distanceFilter = minimumDistanceFilter
        
        logger.notice("LocationManager initialized")
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.notice("Location authorization status changed: \(manager.authorizationStatus.rawValue)")
        
        if manager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Always update the lastLocation property
        lastLocation = location
        
        // Call the location update callback
        onLocationUpdate?(location.coordinate)
        
        // Only log if this is a significant change or enough time has passed
        let now = Date()
        let shouldLog = shouldLogLocationUpdate(location: location, currentTime: now)
        
        if shouldLog {
            logger.notice("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            lastLoggedLocation = location
            lastLogTimestamp = now
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location manager failed with error: \(error.localizedDescription)")
    }
    
    // Helper method to determine if we should log this location update
    private func shouldLogLocationUpdate(location: CLLocation, currentTime: Date) -> Bool {
        // If we haven't logged anything yet, log this one
        guard let lastLocation = lastLoggedLocation else {
            return true
        }
        
        // Check if enough time has passed since the last log
        let timeElapsed = currentTime.timeIntervalSince(lastLogTimestamp)
        if timeElapsed >= minimumLogInterval {
            // Check if the distance is significant enough to log
            let distance = location.distance(from: lastLocation)
            return distance >= minimumDistanceFilter
        }
        
        return false
    }
} 