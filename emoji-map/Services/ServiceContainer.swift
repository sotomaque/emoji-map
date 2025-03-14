//
//  ServiceContainer.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import os.log

@MainActor
class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()
    
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "ServiceContainer")
    
    // MARK: - Services
    let userPreferences: UserPreferences
    let networkService: NetworkServiceProtocol
    let placesService: PlacesServiceProtocol
    let locationManager: LocationManager
    
    // MARK: - View Models
    lazy var homeViewModel: HomeViewModel = {
        return HomeViewModel(placesService: placesService)
    }()
    
    // MARK: - Initialization
    private init() {
        // Initialize core services
        userPreferences = UserPreferences()
        
        // Initialize network layer
        let httpClient = DefaultHTTPClient(session: URLSession.shared)
        networkService = NetworkService(httpClient: httpClient)
        
        // Initialize dependent services
        placesService = PlacesService(networkService: networkService)
        locationManager = LocationManager()
        
        // Log initialization
        logger.notice("ServiceContainer initialized with all services")
    }
    
    // MARK: - Methods
    
    /// Resets all services to their initial state
    func resetAllServices() {
        // Reset user preferences
        userPreferences.resetAllData()
        
        // Clear places cache
        placesService.clearCache()
        
        logger.notice("All services reset")
    }
}
