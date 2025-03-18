import XCTest
import Combine
import CoreLocation
@testable import emoji_map
import Clerk

class ClerkAuthenticationTests: XCTestCase {
    // Properties for testing
    var viewModel: HomeViewModel!
    var mockPlacesService: MockPlacesService!
    var mockUserPreferences: UserPreferences!
    var mockNetworkService: MockNetworkService!
    var mockClerkService: MockClerkService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() async throws {
        try await super.setUp()
        mockPlacesService = MockPlacesService()
        mockUserPreferences = UserPreferences()
        mockNetworkService = MockNetworkService()
        
        // By default, create a mock clerk with no authentication
        mockClerkService = MockClerkService(isAuthenticated: false)
    }
    
    override func tearDown() {
        viewModel = nil
        mockPlacesService = nil
        mockUserPreferences = nil
        mockNetworkService = nil
        mockClerkService = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    /// Test that when the view model initializes with an authenticated user,
    /// it fetches user data including ratings and favorites
    func testFetchesUserDataWhenAuthenticated() async throws {
        // Given an authenticated user in Clerk
        // Explicitly setting isAdmin to false for this test
        mockClerkService = MockClerkService(isAuthenticated: true, isAdmin: false)
        
        // And mock user data with favorites and ratings
        let favorites = [
            FavoriteResponse(id: "fav1", userId: "test_user_123", placeId: "place1", createdAt: nil),
            FavoriteResponse(id: "fav2", userId: "test_user_123", placeId: "place2", createdAt: nil)
        ]
        
        let ratings = [
            RatingResponse(id: "rat1", userId: "test_user_123", placeId: "place1", rating: 4, createdAt: nil, updatedAt: nil),
            RatingResponse(id: "rat2", userId: "test_user_123", placeId: "place2", rating: 5, createdAt: nil, updatedAt: nil)
        ]
        
        mockNetworkService.setupMockUserResponse(
            userId: "test_user_123",
            email: "test@example.com",
            favorites: favorites,
            ratings: ratings
        )
        
        // When we create a new HomeViewModel with our mocked dependencies
        viewModel = await HomeViewModel(
            placesService: mockPlacesService,
            userPreferences: mockUserPreferences,
            networkService: mockNetworkService,
            clerkService: mockClerkService
        )
        
        // Allow time for async operations to complete
        try await Task.sleep(for: .seconds(0.5))
        
        // Then it should have fetched user data
        XCTAssertTrue(mockNetworkService.fetchCalled, "fetch should be called for user data")
        XCTAssertEqual(mockNetworkService.lastEndpoint, .user, "The endpoint should be the user endpoint")
        
        // And it should have passed the session token as auth token
        XCTAssertEqual(mockNetworkService.lastAuthToken, "mock_session_token_for_testing", "The session token should be used as auth token")
        
        // And there should be no query items (we're using token-based auth now)
        XCTAssertNil(mockNetworkService.lastQueryItems, "No query items should be used with token auth")
        
        // And the favorites should be synchronized with UserPreferences
        XCTAssertTrue(mockUserPreferences.isFavorite(placeId: "place1"), "place1 should be favorited")
        XCTAssertTrue(mockUserPreferences.isFavorite(placeId: "place2"), "place2 should be favorited")
        
        // And the ratings should be synchronized with UserPreferences
        XCTAssertEqual(mockUserPreferences.getRating(placeId: "place1"), 4, "place1 should have a rating of 4")
        XCTAssertEqual(mockUserPreferences.getRating(placeId: "place2"), 5, "place2 should have a rating of 5")
        
        // And the admin status should be false (default)
        let isAdmin = await viewModel.isAdmin
        XCTAssertFalse(isAdmin, "Admin status should be false by default")
    }
    
    /// Test that when the view model initializes with no authenticated user,
    /// it does not fetch user data or make any network requests
    func testDoesNotFetchUserDataWhenNotAuthenticated() async throws {
        // Given no authenticated user in Clerk
        mockClerkService = MockClerkService(isAuthenticated: false)
        
        // When we create a new HomeViewModel with our mocked dependencies
        viewModel = await HomeViewModel(
            placesService: mockPlacesService,
            userPreferences: mockUserPreferences,
            networkService: mockNetworkService,
            clerkService: mockClerkService
        )
        
        // Allow time for async operations to complete
        try await Task.sleep(for: .seconds(0.5))
        
        // Then it should not have fetched user data
        XCTAssertFalse(mockNetworkService.fetchCalled, "fetch should not be called when no user is authenticated")
        XCTAssertNil(mockNetworkService.lastEndpoint, "No endpoint should be called")
    }
    
    /// Test that when a user has admin status, the isAdmin property is properly set
    func testAdminStatusIsPropagated() async throws {
        // Given an authenticated user with admin status in Clerk
        mockClerkService = MockClerkService(isAuthenticated: true, isAdmin: true)
        
        // When we create a new HomeViewModel with our mocked dependencies
        viewModel = await HomeViewModel(
            placesService: mockPlacesService,
            userPreferences: mockUserPreferences,
            networkService: mockNetworkService,
            clerkService: mockClerkService
        )
        
        // Allow time for async operations to complete
        try await Task.sleep(for: .seconds(0.5))
        
        // Then the view model should have the admin status
        let isAdmin = await viewModel.isAdmin
        XCTAssertTrue(isAdmin, "Admin status should be true when Clerk reports admin: true")
    }
} 