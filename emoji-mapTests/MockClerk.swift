import Foundation
import SwiftUI
import Clerk
@testable import emoji_map

/// Mock implementation of ClerkService for testing
class MockClerkService: ClerkService {
    // Mock state
    var isLoaded: Bool = true
    var userId: String?
    var isAdmin: Bool = false
    
    // We can't easily construct a Clerk.User, so return nil for the user property
    // but provide the ID separately for testing
    var user: User? {
        return nil
    }
    
    init(isAuthenticated: Bool = false, isLoaded: Bool = true, isAdmin: Bool = false) {
        self.isLoaded = isLoaded
        self.isAdmin = isAdmin
        
        if isAuthenticated {
            self.userId = "test_user_123" // Use a test user ID
        } else {
            self.userId = nil
        }
    }
    
    func getSessionToken() async throws -> String? {
        // For tests, return a mock token if the user is authenticated
        if userId != nil {
            return "mock_session_token_for_testing"
        }
        return nil
    }
    
    func getSessionId() async throws -> String? {
        // For tests, return a mock session ID if the user is authenticated
        if userId != nil {
            return "mock_session_id_for_testing"
        }
        return nil
    }
}

// Simple implementation for AnyCodable if needed
struct MockAnyCodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
}

/// Mock implementation of the Clerk class for UI testing
class MockClerk {
    var isLoaded: Bool
    var isSignedIn: Bool
    var mockUser: MockClerkUserModel?
    var mockPublicMetadata: [String: MockAnyCodable]?
    
    init(isLoaded: Bool = true, isSignedIn: Bool = false) {
        self.isLoaded = isLoaded
        self.isSignedIn = isSignedIn
        self.mockUser = nil
    }
    
    func setMockUser(id: String, email: String, username: String? = nil, isAdmin: Bool = false) {
        // Create public metadata with admin status
        let publicMetadata: [String: MockAnyCodable] = isAdmin ? ["admin": MockAnyCodable(true)] : [:]
        
        self.mockUser = MockClerkUserModel(
            id: id,
            emailAddresses: [
                MockClerkEmailAddressModel(id: "email_1", emailAddress: email)
            ],
            username: username,
            publicMetadata: publicMetadata
        )
        
        self.mockPublicMetadata = publicMetadata
        self.isSignedIn = true
    }
    
    func signOut() async throws {
        self.mockUser = nil
        self.isSignedIn = false
    }
}

/// A mock email address for Clerk user (renamed to avoid conflicts)
struct MockClerkEmailAddressModel: Identifiable {
    let id: String
    let emailAddress: String
}

/// A mock user for Clerk testing (renamed to avoid conflicts)
class MockClerkUserModel: Identifiable {
    let id: String
    let emailAddresses: [MockClerkEmailAddressModel]
    let username: String?
    let publicMetadata: [String: MockAnyCodable]?
    
    init(id: String, emailAddresses: [MockClerkEmailAddressModel], username: String? = nil, publicMetadata: [String: MockAnyCodable]? = nil) {
        self.id = id
        self.emailAddresses = emailAddresses
        self.username = username
        self.publicMetadata = publicMetadata
    }
}

/// A mock SignIn class for testing
enum MockSignIn {
    static func authenticateWithIdToken(provider: OAuthProvider, idToken: String) async throws {
        // This is a mock, so it doesn't actually do anything
        // The test would verify this was called
    }
}

/// Extension to create a custom PreviewProvider-like environment for testing
extension View {
    func withMockClerkEnvironment(_ mockClerk: MockClerk) -> some View {
        self.environment(\.mockClerk, mockClerk)
    }
}

/// Environment key for mock Clerk
struct MockClerkEnvironmentKey: EnvironmentKey {
    static let defaultValue = MockClerk()
}

/// Extension to add mock Clerk to environment values
extension EnvironmentValues {
    var mockClerk: MockClerk {
        get { self[MockClerkEnvironmentKey.self] }
        set { self[MockClerkEnvironmentKey.self] = newValue }
    }
} 