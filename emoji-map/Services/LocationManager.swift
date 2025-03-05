//
//  LocationManager.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//


import CoreLocation

// Protocol for LocationManager to enable mocking in tests
protocol LocationManagerProtocol: AnyObject {
    var location: CLLocation? { get }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func requestLocationAuthorization()
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
    
    // Initializer with dependency injection for testing
    init(locationManager: CLLocationManager = CLLocationManager(),
         queue: DispatchQueue = DispatchQueue(label: "com.emoji-map.locationQueue")) {
        self.clLocationManager = locationManager
        self.locationQueue = queue
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
    
    // Public method to start location updates
    func startUpdatingLocation() {
        clLocationManager.startUpdatingLocation()
    }
    
    // Public method to stop location updates
    func stopUpdatingLocation() {
        clLocationManager.stopUpdatingLocation()
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
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
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
        handleAuthorizationChange(manager.authorizationStatus)
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
