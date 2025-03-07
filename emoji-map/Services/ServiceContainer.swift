import Foundation
import Combine

/// A class to observe changes to UserPreferences and notify interested parties
@MainActor
class UserPreferencesObserver {
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to notifications
        NotificationCenter.default.publisher(for: UserPreferences.favoritesChangedNotification)
            .sink { [weak self] notification in
                self?.handleFavoritesChanged(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UserPreferences.ratingsChangedNotification)
            .sink { [weak self] notification in
                self?.handleRatingsChanged(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleFavoritesChanged(_ notification: Notification) {
        // Force UI updates in all view models
        DispatchQueue.main.async {
            // Log the change
            print("UserPreferencesObserver: Favorites changed, updating all view models")
            
            // Update all view models
            ServiceContainer.shared.updateAllViewModels()
        }
    }
    
    private func handleRatingsChanged(_ notification: Notification) {
        // Force UI updates in all view models
        DispatchQueue.main.async {
            // Log the change
            print("UserPreferencesObserver: Ratings changed, updating all view models")
            
            // Update all view models
            ServiceContainer.shared.updateAllViewModels()
        }
    }
}

/// A container for all service instances in the app
@MainActor
class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()
    
    // MARK: - Services
    let googlePlacesService: GooglePlacesServiceProtocol
    let userPreferences: UserPreferences
    let hapticsManager: HapticsManager
    let mapAppUtility: MapAppUtility
    private let preferencesObserver: UserPreferencesObserver
    
    // MARK: - View Models
    let mapViewModel: MapViewModel
    
    // MARK: - Initialization
    private init() {
        // Initialize services
        googlePlacesService = GooglePlacesService()
        userPreferences = UserPreferences()
        hapticsManager = HapticsManager.shared
        mapAppUtility = MapAppUtility.shared
        preferencesObserver = UserPreferencesObserver()
        
        // Initialize view models
        mapViewModel = MapViewModel(
            googlePlacesService: googlePlacesService,
            userPreferences: userPreferences
        )
        
        print("ServiceContainer initialized")
    }
    
    // MARK: - Methods
    
    /// Resets all services to their initial state
    func resetAllServices() {
        // Reset user preferences
        userPreferences.resetAllData()
        
        print("All services reset")
    }
    
    /// Updates all view models when preferences change
    func updateAllViewModels() {
        // Log the update
        print("ServiceContainer: Updating all view models")
        
        // This will be called when preferences change
        // We'll use NotificationCenter to broadcast this to all view models
        NotificationCenter.default.post(name: Notification.Name("ServiceContainer.updateAllViewModels"), object: nil)
        
        // Force an immediate UI refresh on the main thread
        DispatchQueue.main.async {
            // Post the notification again after a short delay to ensure all view models are updated
            // This helps with race conditions where some view models might not be ready yet
            NotificationCenter.default.post(name: Notification.Name("ServiceContainer.updateAllViewModels"), object: nil)
        }
    }
} 