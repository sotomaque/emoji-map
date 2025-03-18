import Foundation
import Combine
@testable import emoji_map

/// A mock implementation of NetworkServiceProtocol for testing purposes
class MockNetworkService: NetworkServiceProtocol {
    // Track which methods were called
    var fetchCalled = false
    var fetchWithPublisherCalled = false
    var postCalled = false
    var putCalled = false
    var deleteCalled = false
    
    // Track method parameters
    var lastEndpoint: APIEndpoint?
    var lastQueryItems: [URLQueryItem]?
    var lastAuthToken: String?
    var lastBody: Any?
    
    // Mock responses
    var mockUserResponse: UserResponse?
    var mockError: Error?
    
    // Reset tracking information
    func resetTracking() {
        fetchCalled = false
        fetchWithPublisherCalled = false
        postCalled = false
        putCalled = false
        deleteCalled = false
        
        lastEndpoint = nil
        lastQueryItems = nil
        lastAuthToken = nil
        lastBody = nil
    }
    
    // MARK: - NetworkServiceProtocol Methods
    
    func fetch<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil, authToken: String? = nil) async throws -> T {
        fetchCalled = true
        lastEndpoint = endpoint
        lastQueryItems = queryItems
        lastAuthToken = authToken
        
        // If there's a mock error, throw it
        if let error = mockError {
            throw error
        }
        
        // Return the appropriate mock response based on the endpoint and type
        switch endpoint {
        case .user:
            if T.self == UserResponse.self, let response = mockUserResponse {
                return response as! T
            }
        default:
            break
        }
        
        // Fallback for cases not explicitly handled
        throw NetworkError.invalidResponse
    }
    
    func fetchWithPublisher<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil, authToken: String? = nil) -> AnyPublisher<T, Error> {
        fetchWithPublisherCalled = true
        lastEndpoint = endpoint
        lastQueryItems = queryItems
        lastAuthToken = authToken
        
        if let error = mockError {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        // For UserResponse
        if T.self == UserResponse.self, let response = mockUserResponse as? T {
            return Just(response)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: NetworkError.invalidResponse).eraseToAnyPublisher()
    }
    
    func post<T: Decodable, U: Encodable>(endpoint: APIEndpoint, body: U, queryItems: [URLQueryItem]? = nil, authToken: String? = nil) async throws -> T {
        postCalled = true
        lastEndpoint = endpoint
        lastQueryItems = queryItems
        lastAuthToken = authToken
        lastBody = body
        
        if let error = mockError {
            throw error
        }
        
        // Return empty response for simplicity
        if T.self == EmptyResponse.self {
            return EmptyResponse.empty as! T
        }
        
        throw NetworkError.invalidResponse
    }
    
    func put<T: Decodable, U: Encodable>(endpoint: APIEndpoint, body: U, queryItems: [URLQueryItem]? = nil, authToken: String? = nil) async throws -> T {
        putCalled = true
        lastEndpoint = endpoint
        lastQueryItems = queryItems
        lastAuthToken = authToken
        lastBody = body
        
        if let error = mockError {
            throw error
        }
        
        throw NetworkError.invalidResponse
    }
    
    func delete<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil, authToken: String? = nil) async throws -> T {
        deleteCalled = true
        lastEndpoint = endpoint
        lastQueryItems = queryItems
        lastAuthToken = authToken
        
        if let error = mockError {
            throw error
        }
        
        throw NetworkError.invalidResponse
    }
    
    // MARK: - Mock Response Helpers
    
    /// Set up a mock user response with the given user ID and optionally favorites and ratings
    func setupMockUserResponse(userId: String = "test_user_123", 
                               email: String = "test@example.com",
                               favorites: [FavoriteResponse] = [], 
                               ratings: [RatingResponse] = []) {
        let userData = UserData(
            id: userId,
            email: email,
            username: "testuser",
            firstName: "Test",
            lastName: "User",
            imageUrl: nil,
            createdAt: nil,
            updatedAt: nil,
            favorites: favorites,
            ratings: ratings
        )
        
        mockUserResponse = UserResponse(user: userData)
    }
} 