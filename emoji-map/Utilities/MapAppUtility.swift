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
            print("DEBUG: Apple Maps is always considered installed")
            return true // Apple Maps is always available
        }
        
        guard let url = URL(string: urlScheme) else { 
            print("DEBUG: Failed to create URL from scheme: \(urlScheme)")
            return false 
        }
        let canOpen = UIApplication.shared.canOpenURL(url)
        print("DEBUG: Can open \(self.rawValue) with scheme \(urlScheme): \(canOpen)")
        return canOpen
    }
}

/// Utility class for handling map-related operations
class MapAppUtility {
    static let shared = MapAppUtility()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "MapAppUtility")
    
    private init() {
        // Register URL schemes for proper checking
        // Note: This is now handled in the project configuration
        logger.info("MapAppUtility initialized")
        
        // Debug check for URL schemes
        print("DEBUG: Checking URL schemes...")
        for app in MapApp.allCases {
            if let url = URL(string: app.urlScheme) {
                let canOpen = UIApplication.shared.canOpenURL(url)
                print("DEBUG: Can open \(app.rawValue) with scheme \(app.urlScheme): \(canOpen)")
            } else {
                print("DEBUG: Invalid URL scheme for \(app.rawValue): \(app.urlScheme)")
            }
        }
    }
    
    /// Get all installed map apps
    func getInstalledMapApps() -> [MapApp] {
        let apps = MapApp.allCases.filter { $0.isInstalled }
        logger.info("Found \(apps.count) installed map apps: \(apps.map { $0.rawValue }.joined(separator: ", "))")
        return apps
    }
    
    /// Open the specified location in the given map app
    func openInMapApp(mapApp: MapApp, coordinate: CLLocationCoordinate2D, name: String) {
        logger.info("Attempting to open \(mapApp.rawValue) for location: \(name) at coordinates: \(coordinate.latitude), \(coordinate.longitude)")
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch mapApp {
        case .appleMaps:
            // Try both methods for Apple Maps to ensure it works
            print("DEBUG: Trying to open Apple Maps...")
            
            // Method 1: Direct URL scheme
            let urlString = "maps://?q=\(encodedName)&ll=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d"
            logger.info("Apple Maps URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                logger.info("Opening Apple Maps with URL: \(url)")
                print("DEBUG: Attempting to open Apple Maps with URL: \(url)")
                
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            print("DEBUG: Successfully opened Apple Maps via URL")
                        } else {
                            print("DEBUG: Failed to open Apple Maps via URL, trying MKMapItem method")
                            
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
                print("DEBUG: Failed to create URL for Apple Maps, trying MKMapItem method")
                
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
            logger.info("Google Maps URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    logger.info("Opening Google Maps with URL: \(url)")
                    print("DEBUG: Attempting to open Google Maps with URL: \(url)")
                    
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("DEBUG: Successfully opened Google Maps")
                            } else {
                                print("DEBUG: Failed to open Google Maps")
                            }
                        }
                    }
                } else {
                    logger.warning("Google Maps app not installed, redirecting to App Store")
                    print("DEBUG: Google Maps not installed, redirecting to App Store")
                    
                    // Open App Store if Google Maps is not installed
                    if let appStoreURL = URL(string: mapApp.appStoreURL) {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(appStoreURL)
                        }
                    }
                }
            } else {
                logger.error("Failed to create URL for Google Maps with string: \(urlString)")
                print("DEBUG: Failed to create URL for Google Maps")
            }
            
        case .waze:
            // Waze URL format
            let urlString = "waze://?ll=\(coordinate.latitude),\(coordinate.longitude)&navigate=yes"
            logger.info("Waze URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    logger.info("Opening Waze with URL: \(url)")
                    print("DEBUG: Attempting to open Waze with URL: \(url)")
                    
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("DEBUG: Successfully opened Waze")
                            } else {
                                print("DEBUG: Failed to open Waze")
                            }
                        }
                    }
                } else {
                    logger.warning("Waze app not installed, redirecting to App Store")
                    print("DEBUG: Waze not installed, redirecting to App Store")
                    
                    // Open App Store if Waze is not installed
                    if let appStoreURL = URL(string: mapApp.appStoreURL) {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(appStoreURL)
                        }
                    }
                }
            } else {
                logger.error("Failed to create URL for Waze with string: \(urlString)")
                print("DEBUG: Failed to create URL for Waze")
            }
        }
    }
    
    // Test method to verify URL scheme handling
    func testURLSchemes() {
        print("DEBUG: Testing URL schemes...")
        
        // Test Apple Maps
        if let url = URL(string: "maps://") {
            UIApplication.shared.open(url, options: [:]) { success in
                print("DEBUG: Opening Apple Maps test result: \(success)")
            }
        }
        
        // Test Google Maps
        if let url = URL(string: "comgooglemaps://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    print("DEBUG: Opening Google Maps test result: \(success)")
                }
            } else {
                print("DEBUG: Cannot open Google Maps URL")
            }
        }
        
        // Test Waze
        if let url = URL(string: "waze://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    print("DEBUG: Opening Waze test result: \(success)")
                }
            } else {
                print("DEBUG: Cannot open Waze URL")
            }
        }
    }
} 