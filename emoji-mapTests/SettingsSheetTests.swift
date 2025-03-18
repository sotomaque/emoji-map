import XCTest
import SwiftUI
import AuthenticationServices
@testable import emoji_map

/// Test class for the SettingsSheet view
@MainActor
final class SettingsSheetTests: XCTestCase {
    var viewModel: HomeViewModel!
    var userPreferences: UserPreferences!
    
    override func setUp() async throws {
        userPreferences = UserPreferences()
        viewModel = HomeViewModel(
            placesService: MockPlacesService(),
            userPreferences: userPreferences,
            networkService: MockNetworkService()
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        userPreferences = nil
    }
    
    func testSignInCallsViewModelMethod() async throws {
        let spyViewModel = SpyHomeViewModel(
            placesService: MockPlacesService(),
            userPreferences: userPreferences,
            networkService: MockNetworkService()
        )
        
        // Create a test SettingsSheet with our spy view model
        let testSheet = SettingsSheet(viewModel: spyViewModel)
        
        // Directly call the method that would be triggered by handleSignInWithAppleCompletion
        try await testSheet.signInWithIdentityToken("test_token")
        
        // Verify that the view model's sign in method was called
        XCTAssertTrue(spyViewModel.wasSignInWithAppleCalled, "signInWithApple should be called in the ViewModel")
        
        // Verify that after sign in, fetch user data is called
        XCTAssertTrue(spyViewModel.wasFetchUserDataCalled, "fetchUserData should be called after successful sign in")
    }
    
    // MARK: - Helper Classes
    
    class SpyHomeViewModel: HomeViewModel {
        var wasSignInWithAppleCalled = false
        var wasFetchUserDataCalled = false
        
        override func signInWithApple(idToken: String) async throws {
            wasSignInWithAppleCalled = true
            // Don't call super to avoid actual network calls in tests
        }
        
        override func fetchUserData(networkService: NetworkServiceProtocol? = nil, clerkService: ClerkService? = nil) async {
            wasFetchUserDataCalled = true
            // Don't call super to avoid actual network calls in tests
        }
    }
} 