//
//  NetworkService.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import Combine
import os.log

// MARK: - Network Errors

/// Custom network errors
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case requestFailed(Error)
    case unauthorized
    case rateLimited
    case noInternetConnection
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let statusCode, _):
            return "Server error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .rateLimited:
            return "Rate limit exceeded"
        case .noInternetConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unknown:
            return "Unknown error"
        }
    }
    
    /// Create a NetworkError from an HTTP status code and optional data
    static func from(statusCode: Int, data: Data?) -> NetworkError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 429:
            return .rateLimited
        case 400...499:
            return .serverError(statusCode: statusCode, data: data)
        case 500...599:
            return .serverError(statusCode: statusCode, data: data)
        default:
            return .serverError(statusCode: statusCode, data: data)
        }
    }
    
    /// Create a NetworkError from a URLError
    static func from(urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut:
            return .timeout
        default:
            return .requestFailed(urlError)
        }
    }
}

// MARK: - HTTP Method

/// HTTP methods supported by the API
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - API Endpoint

/// Enum representing API endpoints
enum APIEndpoint {
    case nearbyPlaces
    case placeDetails
    case placePhotos
    
    var path: String {
        switch self {
        case .nearbyPlaces:
            return "api/places/nearby"
        case .placeDetails:
            return "api/places/details"
        case .placePhotos:
            return "api/places/photos"
        }
    }
}

// MARK: - HTTP Client Protocol

/// Protocol defining the HTTP client capabilities
protocol HTTPClient {
    func sendRequest<T: Decodable>(_ request: URLRequest) async throws -> T
    func sendRequest(_ request: URLRequest) async throws -> Data
}

// MARK: - Default HTTP Client Implementation

/// Default implementation of HTTPClient using URLSession
class DefaultHTTPClient: HTTPClient {
    private let session: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "HTTPClient")
    
    init(session: URLSession = .shared) {
        self.session = session
        logger.notice("HTTPClient initialized")
    }
    
    /// Send a request and decode the response to the specified type
    /// - Parameter request: The URLRequest to send
    /// - Returns: Decoded response of type T
    func sendRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await sendRequest(request)
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription)")
            
            if let decodingError = error as? DecodingError {
                logDecodingError(decodingError)
            }
            
            throw NetworkError.decodingError(error)
        }
    }
    
    /// Send a request and return the raw data
    /// - Parameter request: The URLRequest to send
    /// - Returns: Raw response data
    func sendRequest(_ request: URLRequest) async throws -> Data {
        logger.notice("Sending request to: \(request.url?.absoluteString ?? "unknown URL")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not an HTTP response")
                throw NetworkError.invalidResponse
            }
            
            logger.notice("Received response with status code: \(httpResponse.statusCode)")
            
            // Check for successful status code (200-299)
            guard (200...299).contains(httpResponse.statusCode) else {
                let error = NetworkError.from(statusCode: httpResponse.statusCode, data: data)
                logger.error("Server returned error: \(error.localizedDescription)")
                throw error
            }
            
            // Log the raw response for debugging (limited to first 200 characters)
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.notice("Raw response: \(jsonString.prefix(200))...")
            }
            
            return data
        } catch let urlError as URLError {
            let networkError = NetworkError.from(urlError: urlError)
            logger.error("URL error: \(networkError.localizedDescription)")
            throw networkError
        } catch let networkError as NetworkError {
            throw networkError
        } catch {
            logger.error("Unknown error: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }
    }
    
    /// Log detailed information about decoding errors
    /// - Parameter error: The decoding error to log
    private func logDecodingError(_ error: DecodingError) {
        let logger: Logger = self.logger
        
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Type mismatch: \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Value not found: \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Key not found: \(String(describing: key)), path: \(path), debug description: \(context.debugDescription)")
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Data corrupted: path: \(path), debug description: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Builder

/// Builder for creating URLRequests
struct RequestBuilder {
    private var baseURL: URL
    private var path: String
    private var method: HTTPMethod = .get
    private var queryItems: [URLQueryItem]?
    private var headers: [String: String] = [:]
    private var body: Data?
    private var timeoutInterval: TimeInterval = 30
    
    init(baseURL: URL) {
        self.baseURL = baseURL
        self.path = ""
    }
    
    /// Set the path for the request
    /// - Parameter path: The path to append to the base URL
    /// - Returns: Updated RequestBuilder
    func with(path: String) -> RequestBuilder {
        var builder = self
        builder.path = path
        return builder
    }
    
    /// Set the HTTP method for the request
    /// - Parameter method: The HTTP method
    /// - Returns: Updated RequestBuilder
    func with(method: HTTPMethod) -> RequestBuilder {
        var builder = self
        builder.method = method
        return builder
    }
    
    /// Set the query items for the request
    /// - Parameter queryItems: The query items
    /// - Returns: Updated RequestBuilder
    func with(queryItems: [URLQueryItem]?) -> RequestBuilder {
        var builder = self
        builder.queryItems = queryItems
        return builder
    }
    
    /// Set a header for the request
    /// - Parameters:
    ///   - key: The header key
    ///   - value: The header value
    /// - Returns: Updated RequestBuilder
    func withHeader(key: String, value: String) -> RequestBuilder {
        var builder = self
        builder.headers[key] = value
        return builder
    }
    
    /// Set the request body
    /// - Parameter body: The request body data
    /// - Returns: Updated RequestBuilder
    func with(body: Data?) -> RequestBuilder {
        var builder = self
        builder.body = body
        return builder
    }
    
    /// Set the request body as a JSON encodable object
    /// - Parameter jsonObject: The object to encode as JSON
    /// - Returns: Updated RequestBuilder
    func withJSONBody<T: Encodable>(_ jsonObject: T) -> RequestBuilder {
        var builder = self
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            builder.body = try encoder.encode(jsonObject)
            builder = builder.withHeader(key: "Content-Type", value: "application/json")
        } catch {
            // Just log the error, the build will continue but the body won't be set
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "RequestBuilder")
            logger.error("Failed to encode JSON body: \(error.localizedDescription)")
        }
        return builder
    }
    
    /// Set the timeout interval for the request
    /// - Parameter seconds: The timeout interval in seconds
    /// - Returns: Updated RequestBuilder
    func withTimeout(seconds: TimeInterval) -> RequestBuilder {
        var builder = self
        builder.timeoutInterval = seconds
        return builder
    }
    
    /// Build the URLRequest
    /// - Returns: The built URLRequest or throws an error if the URL is invalid
    func build() throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        
        // Add default headers
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = body
        
        return request
    }
}

// MARK: - Network Service Protocol

/// Protocol defining the network service capabilities
protocol NetworkServiceProtocol {
    func fetch<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]?) async throws -> T
    func fetchWithPublisher<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]?) -> AnyPublisher<T, Error>
    func post<T: Decodable, U: Encodable>(endpoint: APIEndpoint, body: U, queryItems: [URLQueryItem]?) async throws -> T
    func put<T: Decodable, U: Encodable>(endpoint: APIEndpoint, body: U, queryItems: [URLQueryItem]?) async throws -> T
    func delete<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]?) async throws -> T
}

// MARK: - Network Service Implementation

/// Service responsible for handling network requests
class NetworkService: NetworkServiceProtocol {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "NetworkService")
    private let httpClient: HTTPClient
    
    // MARK: - Initialization
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
        logger.notice("NetworkService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Fetch data from an API endpoint using async/await
    /// - Parameters:
    ///   - endpoint: The API endpoint to fetch from
    ///   - queryItems: Optional query parameters
    /// - Returns: Decoded response of type T
    func fetch<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try createRequest(for: endpoint, method: .get, queryItems: queryItems)
        return try await httpClient.sendRequest(request)
    }
    
    /// Post data to an API endpoint using async/await
    /// - Parameters:
    ///   - endpoint: The API endpoint to post to
    ///   - body: The request body
    ///   - queryItems: Optional query parameters
    /// - Returns: Decoded response of type T
    func post<T: Decodable, U: Encodable>(endpoint: APIEndpoint, body: U, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request: URLRequest = try createRequest(for: endpoint, method: .post, body: body, queryItems: queryItems)
        return try await httpClient.sendRequest(request)
    }
    
    /// Put data to an API endpoint using async/await
    /// - Parameters:
    ///   - endpoint: The API endpoint to put to
    ///   - body: The request body
    ///   - queryItems: Optional query parameters
    /// - Returns: Decoded response of type T
    func put<T: Decodable, U: Encodable>(endpoint: APIEndpoint, body: U, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request: URLRequest = try createRequest(for: endpoint, method: .put, body: body, queryItems: queryItems)
        return try await httpClient.sendRequest(request)
    }
    
    /// Delete data from an API endpoint using async/await
    /// - Parameters:
    ///   - endpoint: The API endpoint to delete from
    ///   - queryItems: Optional query parameters
    /// - Returns: Decoded response of type T
    func delete<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try createRequest(for: endpoint, method: .delete, queryItems: queryItems)
        return try await httpClient.sendRequest(request)
    }
    
    /// Fetch data from an API endpoint using Combine
    /// - Parameters:
    ///   - endpoint: The API endpoint to fetch from
    ///   - queryItems: Optional query parameters
    /// - Returns: Publisher that emits decoded response of type T or error
    func fetchWithPublisher<T: Decodable>(endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil) -> AnyPublisher<T, Error> {
        do {
            let request = try createRequest(for: endpoint, method: .get, queryItems: queryItems)
            
            return URLSession.shared.dataTaskPublisher(for: request)
                .subscribe(on: DispatchQueue.global(qos: .userInitiated))
                .tryMap { [weak self] data, response -> Data in
                    guard let self = self else { throw NetworkError.unknown }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.logger.error("Response is not an HTTP response")
                        throw NetworkError.invalidResponse
                    }
                    
                    self.logger.notice("Received response with status code: \(httpResponse.statusCode)")
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        let error = NetworkError.from(statusCode: httpResponse.statusCode, data: data)
                        self.logger.error("Server returned error: \(error.localizedDescription)")
                        throw error
                    }
                    
                    // Log the raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        self.logger.notice("Raw response: \(jsonString.prefix(200))...")
                    }
                    
                    return data
                }
                .decode(type: T.self, decoder: JSONDecoder())
                .mapError { [weak self] error -> Error in
                    guard let self = self else { return NetworkError.unknown }
                    
                    if let decodingError = error as? DecodingError {
                        self.logDecodingError(decodingError)
                        return NetworkError.decodingError(decodingError)
                    } else if let urlError = error as? URLError {
                        let networkError = NetworkError.from(urlError: urlError)
                        self.logger.error("URL error: \(networkError.localizedDescription)")
                        return networkError
                    } else if let networkError = error as? NetworkError {
                        return networkError
                    } else {
                        self.logger.error("Network request failed: \(error.localizedDescription)")
                        return NetworkError.requestFailed(error)
                    }
                }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail<T, Error>(error: error).eraseToAnyPublisher()
        }
    }
    
    // MARK: - Private Methods
    
    /// Create a URLRequest for the given endpoint and parameters
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: The HTTP method
    ///   - body: Optional request body
    ///   - queryItems: Optional query parameters
    /// - Returns: URLRequest
    private func createRequest<T: Encodable>(
        for endpoint: APIEndpoint,
        method: HTTPMethod,
        body: T? = nil,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var builder: RequestBuilder = RequestBuilder(baseURL: Configuration.backendURL)
            .with(path: endpoint.path)
            .with(method: method)
            .with(queryItems: queryItems)
            .withTimeout(seconds: 30)
        
        if let body = body {
            builder = builder.withJSONBody(body)
        }
        
        return try builder.build()
    }
    
    /// Create a URLRequest for the given endpoint and parameters (non-generic version)
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - method: The HTTP method
    ///   - queryItems: Optional query parameters
    /// - Returns: URLRequest
    private func createRequest(
        for endpoint: APIEndpoint,
        method: HTTPMethod,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        let builder: RequestBuilder = RequestBuilder(baseURL: Configuration.backendURL)
            .with(path: endpoint.path)
            .with(method: method)
            .with(queryItems: queryItems)
            .withTimeout(seconds: 30)
        
        return try builder.build()
    }
    
    /// Log detailed information about decoding errors
    /// - Parameter error: The decoding error to log
    private func logDecodingError(_ error: DecodingError) {
        let logger: Logger = self.logger
        
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Type mismatch: \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Value not found: \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Key not found: \(String(describing: key)), path: \(path), debug description: \(context.debugDescription)")
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Data corrupted: path: \(path), debug description: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error: \(error.localizedDescription)")
        }
    }
    
    private func logDecodingError(_ error: DecodingError, for url: URL) {
        let logger: Logger = self.logger
        
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Type mismatch: \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Value not found: \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Key not found: \(String(describing: key)), path: \(path), debug description: \(context.debugDescription)")
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Data corrupted: path: \(path), debug description: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error: \(error.localizedDescription)")
        }
    }
    
    private func logDecodingError(_ error: DecodingError, for data: Data) {
        let logger: Logger = self.logger
        
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Type mismatch: expected \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Value not found: expected \(String(describing: type)), path: \(path), debug description: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Key not found: \(String(describing: key)), path: \(path), debug description: \(context.debugDescription)")
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("Data corrupted: path: \(path), debug description: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error: \(error.localizedDescription)")
        }
    }
} 