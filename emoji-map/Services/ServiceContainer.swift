import Foundation

/// A container for all service instances in the app
class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()
    
    // MARK: - Services
    let googlePlacesService: GooglePlacesServiceProtocol
    let userPreferences: UserPreferences
    let hapticsManager: HapticsManager
    let mapAppUtility: MapAppUtility
    
    // MARK: - Initialization
    private init() {
        // Initialize services
        googlePlacesService = GooglePlacesService()
        userPreferences = UserPreferences()
        hapticsManager = HapticsManager.shared
        mapAppUtility = MapAppUtility.shared
        
        print("ServiceContainer initialized")
    }
    
    // MARK: - Methods
    
    /// Resets all services to their initial state
    func resetAllServices() {
        // Reset user preferences
        userPreferences.resetAllData()
        
        print("All services reset")
    }
} 