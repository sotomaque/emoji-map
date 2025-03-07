import Foundation
import UIKit
import MapKit
import CoreLocation
import os.log

/// Enum representing different map applications
enum MapApp: String, CaseIterable, Identifiable {
    case appleMaps = "Apple Maps"
    case googleMaps = "Google Maps"
    case waze = "Waze"
    
    var id: String { self.rawValue }
    
    var urlScheme: String {
        switch self {
        case .appleMaps: return "maps://"
        case .googleMaps: return "comgooglemaps://"
        case .waze: return "waze://"
        }
    }
    
    var appStoreURL: String {
        switch self {
        case .appleMaps: return "" // Built-in app
        case .googleMaps: return "https://apps.apple.com/app/google-maps/id585027354"
        case .waze: return "https://apps.apple.com/app/waze-navigation-live-traffic/id323229106"
        }
    }
    
    var isInstalled: Bool {
        if self == .appleMaps {
            return true // Apple Maps is always available
        }
        
        guard let url = URL(string: urlScheme) else { 
            return false 
        }
        return UIApplication.shared.canOpenURL(url)
    }
}

/// Utility class for handling map-related operations
class MapAppUtility {
    // Singleton instance
    static let shared = MapAppUtility()
    
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "MapAppUtility")
    
    private init() {}
    
    /// Get a list of installed map apps
    /// - Returns: Array of installed MapApp values
    func getInstalledMapApps() -> [MapApp] {        
        var installedApps: [MapApp] = []
        
        for app in MapApp.allCases {
            let canOpen = app.isInstalled
            if canOpen {
                installedApps.append(app)
            }
        }
        
        return installedApps
    }
    
    /// Open a location in the specified map app
    /// - Parameters:
    ///   - mapApp: The map app to use
    ///   - coordinate: The location coordinates
    ///   - name: The name of the location
    func openInMapApp(mapApp: MapApp, coordinate: CLLocationCoordinate2D, name: String) {
        logger.info("Opening \(mapApp.rawValue) for location: \(name) at coordinates: \(coordinate.latitude), \(coordinate.longitude)")
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch mapApp {
        case .appleMaps:
            // Try both methods for Apple Maps to ensure it works
            logger.debug("Opening Apple Maps")
            
            // Method 1: Direct URL scheme
            let urlString = "maps://?q=\(encodedName)&ll=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d"
            logger.debug("Apple Maps URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                logger.debug("Opening Apple Maps with URL: \(url)")
                
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            self.logger.info("Successfully opened Apple Maps via URL")
                        } else {
                            self.logger.warning("Failed to open Apple Maps via URL, trying MKMapItem method")
                            
                            // Method 2: MKMapItem as fallback
                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                            mapItem.name = name
                            
                            DispatchQueue.main.async {
                                mapItem.openInMaps(launchOptions: [
                                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                                ])
                            }
                        }
                    }
                }
            } else {
                logger.error("Failed to create URL for Apple Maps with string: \(urlString)")
                
                // Fallback to MKMapItem
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = name
                
                DispatchQueue.main.async {
                    mapItem.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                }
            }
            
        case .googleMaps:
            // Google Maps URL format
            let urlString = "comgooglemaps://?q=\(encodedName)&center=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving"
            logger.debug("Google Maps URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    logger.debug("Opening Google Maps with URL: \(url)")
                    
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                self.logger.info("Successfully opened Google Maps")
                            } else {
                                self.logger.error("Failed to open Google Maps")
                            }
                        }
                    }
                } else {
                    logger.warning("Google Maps app not installed, redirecting to App Store")
                    
                    // Open App Store if Google Maps is not installed
                    if let appStoreURL = URL(string: mapApp.appStoreURL) {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(appStoreURL)
                        }
                    }
                }
            } else {
                logger.error("Failed to create URL for Google Maps with string: \(urlString)")
            }
            
        case .waze:
            // Waze URL format
            let urlString = "waze://?ll=\(coordinate.latitude),\(coordinate.longitude)&navigate=yes"
            logger.debug("Waze URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    logger.debug("Opening Waze with URL: \(url)")
                    
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                self.logger.info("Successfully opened Waze")
                            } else {
                                self.logger.error("Failed to open Waze")
                            }
                        }
                    }
                } else {
                    // Open App Store if Waze is not installed
                    if let appStoreURL = URL(string: mapApp.appStoreURL) {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(appStoreURL)
                        }
                    }
                }
            } else {
                logger.error("Failed to create URL for Waze with string: \(urlString)")
            }
        }
    }
    
    // Test method to verify URL scheme handling
    func testURLSchemes() {
        logger.debug("Testing URL schemes")
        
        // Test Apple Maps
        if let url = URL(string: "maps://") {
            UIApplication.shared.open(url, options: [:]) { success in
                self.logger.debug("Opening Apple Maps test result: \(success)")
            }
        }
        
        // Test Google Maps
        if let url = URL(string: "comgooglemaps://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    self.logger.debug("Opening Google Maps test result: \(success)")
                }
            } else {
                self.logger.debug("Cannot open Google Maps URL")
            }
        }
        
        // Test Waze
        if let url = URL(string: "waze://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    self.logger.debug("Opening Waze test result: \(success)")
                }
            } else {
                self.logger.debug("Cannot open Waze URL")
            }
        }
    }
} 
