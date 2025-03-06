//
//  LocationManager.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//


import CoreLocation
import UIKit

// Protocol for LocationManager to enable mocking in tests
protocol LocationManagerProtocol: AnyObject {
    var location: CLLocation? { get }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var onAuthorizationStatusChange: ((CLAuthorizationStatus) -> Void)? { get set }
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func requestLocationAuthorization()
    func openAppSettings()
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, LocationManagerProtocol {
    // Dependency injection for CLLocationManager to enable testing
    private let clLocationManager: CLLocationManager
    
    // Serial queue for thread synchronization
    private let locationQueue: DispatchQueue
    
    // Private backing property for thread-safe access
    private var locationBackingStore: CLLocation?
    
    // Published property for SwiftUI binding
    @Published private(set) var location: CLLocation?
    
    // Published property for authorization status
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Thread-safe callback property
    private var _onLocationUpdate: ((CLLocation) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)? {
        get {
            locationQueue.sync {
                return _onLocationUpdate
            }
        }
        set {
            locationQueue.async {
                self._onLocationUpdate = newValue
            }
        }
    }
    
    // Thread-safe callback property for authorization status changes
    private var _onAuthorizationStatusChange: ((CLAuthorizationStatus) -> Void)?
    var onAuthorizationStatusChange: ((CLAuthorizationStatus) -> Void)? {
        get {
            locationQueue.sync {
                return _onAuthorizationStatusChange
            }
        }
        set {
            locationQueue.async {
                self._onAuthorizationStatusChange = newValue
            }
        }
    }
    
    // Initializer with dependency injection for testing
    init(locationManager: CLLocationManager = CLLocationManager(),
         queue: DispatchQueue = DispatchQueue(label: "com.emoji-map.locationQueue")) {
        self.clLocationManager = locationManager
        self.locationQueue = queue
        
        // Initialize with current authorization status
        if #available(iOS 14.0, *) {
            self.authorizationStatus = locationManager.authorizationStatus
        } else {
            self.authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        super.init()
        setupLocationManager()
    }
    
    // Extracted setup logic for testability
    func setupLocationManager() {
        clLocationManager.delegate = self
        requestLocationAuthorization()
        startUpdatingLocation()
    }
    
    // Public method to request authorization
    func requestLocationAuthorization() {
        clLocationManager.requestWhenInUseAuthorization()
    }
    
    // Specific method to request when in use authorization
    func requestWhenInUseAuthorization() {
        print("Requesting when in use authorization")
        clLocationManager.requestWhenInUseAuthorization()
    }
    
    // Public method to start location updates
    func startUpdatingLocation() {
        print("Starting location updates")
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        clLocationManager.distanceFilter = 10 // Update when user moves 10 meters
        clLocationManager.startUpdatingLocation()
        
        // If we already have a location, update it immediately
        if let location = clLocationManager.location {
            print("Using existing location from CLLocationManager: \(location.coordinate)")
            updateLocation(location)
        }
    }
    
    // Public method to stop location updates
    func stopUpdatingLocation() {
        clLocationManager.stopUpdatingLocation()
    }
    
    // Public method to open app settings
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // Thread-safe method to update location
    func updateLocation(_ newLocation: CLLocation?) {
        locationQueue.async { [weak self] in
            guard let self = self else { return }
            self.locationBackingStore = newLocation
            
            // Dispatch UI updates to the main thread
            DispatchQueue.main.async {
                self.location = newLocation
                if let newLocation = newLocation {
                    self.onLocationUpdate?(newLocation)
                }
            }
        }
    }
    
    // Thread-safe method to update authorization status
    private func updateAuthorizationStatus(_ newStatus: CLAuthorizationStatus) {
        locationQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Dispatch UI updates to the main thread
            DispatchQueue.main.async {
                self.authorizationStatus = newStatus
                self.onAuthorizationStatusChange?(newStatus)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Only use locations that are recent and have good accuracy
        let howRecent = newLocation.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 15.0, newLocation.horizontalAccuracy < 100 else {
            print("Ignoring location update: too old or poor accuracy")
            return
        }
        
        print("Received location update with accuracy \(newLocation.horizontalAccuracy)m: \(newLocation.coordinate)")
        updateLocation(newLocation)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        handleLocationError(error)
    }
    
    // Extracted error handling for testability
    func handleLocationError(_ error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        // Additional error handling logic can be added here
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        updateAuthorizationStatus(status)
        handleAuthorizationChange(status)
    }
    
    // For iOS 13 and earlier
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        updateAuthorizationStatus(status)
        handleAuthorizationChange(status)
    }
    
    // Extracted authorization handling for testability
    func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied or restricted")
            // Additional denied/restricted handling logic can be added here
        case .notDetermined:
            print("Location authorization not yet determined")
            // Additional not determined handling logic can be added here
        @unknown default:
            print("Unknown authorization status")
        }
    }
}
