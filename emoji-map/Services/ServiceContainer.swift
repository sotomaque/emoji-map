//
//  ServiceContainer.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

@MainActor
class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()
    
    let userPreferences: UserPreferences

    
    // MARK: - Initialization
    private init() {
        userPreferences = UserPreferences()
        
        // Log initialization
        print("ServiceContainer initialized with BackendService")
    }
    
    // MARK: - Methods
    
    /// Resets all services to their initial state
    func resetAllServices() {
        // Reset user preferences
        userPreferences.resetAllData()
        
        print("All services reset")
    }
}
