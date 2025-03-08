import Foundation
import os.log

/// Manages network requests with proper error handling, timeout management, and task tracking
class NetworkRequestManager {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "NetworkRequestManager")
    
    // Track active URLSession tasks for proper cancellation
    private var activeURLSessionTasks: [URLSessionTask] = []
    private let sessionTasksLock = NSLock()
    
    // URLSession to use for network requests
    let session: URLSession
    
    // MARK: - Initialization
    
    /// Initialize with default URLSession
    init() {
        self.session = URLSession.shared
    }
    
    /// Initialize with a custom URLSession (for testing)
    init(session: URLSession) {
        self.session = session
    }
    
    // MARK: - Task Management
    
    /// Add a session task to the tracking list
    func addSessionTask(_ task: URLSessionTask) {
        sessionTasksLock.lock()
        defer { sessionTasksLock.unlock() }
        activeURLSessionTasks.append(task)
        logger.debug("Added URLSession task: \(task.taskIdentifier), total active: \(self.activeURLSessionTasks.count)")
    }
    
    /// Remove a session task from the tracking list
    func removeSessionTask(_ task: URLSessionTask) {
        sessionTasksLock.lock()
        defer { sessionTasksLock.unlock() }
        activeURLSessionTasks.removeAll { $0.taskIdentifier == task.taskIdentifier }
        logger.debug("Removed URLSession task: \(task.taskIdentifier), total active: \(self.activeURLSessionTasks.count)")
    }
    
    /// Cancel all active session tasks
    func cancelAllSessionTasks() {
        sessionTasksLock.lock()
        let tasks = activeURLSessionTasks
        activeURLSessionTasks = []
        sessionTasksLock.unlock()
        
        logger.notice("Cancelling all \(tasks.count) active URLSession tasks")
        
        for task in tasks {
            task.cancel()
        }
    }
    
    // MARK: - URL Construction
    
    /// Create a URL with multiple path components
    func createURLWithPath(baseURL: URL, pathComponents: [String]) -> URL {
        var url = baseURL
        for component in pathComponents {
            url = url.appendingPathComponent(component)
            logger.debug("After adding '\(component)': \(url.absoluteString)")
        }
        return url
    }
    
    /// Create a properly encoded URL with query parameters
    func createURL(baseURL: URL, parameters: [String: String]) -> URL? {
        logger.debug("Creating URL from base: \(baseURL.absoluteString)")
        logger.debug("With parameters: \(parameters)")
        
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        if let url = components?.url {
            logger.debug("Created URL: \(url.absoluteString)")
            return url
        } else {
            logger.error("Failed to create URL from \(baseURL.absoluteString) with parameters: \(parameters)")
            return nil
        }
    }
    
    // MARK: - Error Handling
    
    /// Convert a standard Error to a NetworkError
    func convertToNetworkError(_ error: Error) -> NetworkError {
        let nsError = error as NSError
        
        // Check for specific error types
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorTimedOut:
                logger.notice("Request timed out")
                return .requestTimeout
            case NSURLErrorCancelled:
                logger.notice("Request was cancelled")
                return .requestCancelled
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                logger.notice("Network connection error")
                return .networkConnectionError
            default:
                return .unknownError(error)
            }
        default:
            return .unknownError(error)
        }
    }
    
    /// Handle server errors and extract error messages
    func handleServerError(statusCode: Int, data: Data?) -> NetworkError {
        logger.error("Server error with status code: \(statusCode)")
        
        // Try to extract error message from response
        if let data = data, let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorMessage = errorData["error"] as? String {
            logger.error("Server error message: \(errorMessage)")
            return .apiError(message: errorMessage)
        } else {
            return .serverError(statusCode: statusCode)
        }
    }
    
    // MARK: - Timeout Management
    
    /// Create a timeout task that will execute after the specified time
    func createTimeoutTask(seconds: Double, onTimeout: @escaping () -> Void) -> Task<Void, Never> {
        return Task<Void, Never> { [weak self] in
            guard let self = self else { return }
            
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if !Task.isCancelled {
                    self.logger.warning("Request timed out after \(seconds) seconds")
                    
                    // Cancel all pending requests
                    self.cancelAllSessionTasks()
                    
                    // Call the timeout callback
                    DispatchQueue.main.async {
                        onTimeout()
                    }
                }
            } catch {
                // Task was cancelled or another error occurred
                self.logger.debug("Timeout task cancelled or error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Test Connection
    
    /// Test if a URL is reachable
    /// - Parameter baseURL: The base URL to test
    /// - Returns: True if the URL is reachable, false otherwise
    func testURL(baseURL: URL) async -> Bool {
        let testURL = createURLWithPath(baseURL: baseURL, pathComponents: ["api", "health"])
        
        do {
            var request = URLRequest(url: testURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 5.0 // Short timeout for testing
            
            // Use the session property instead of URLSession.shared
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not an HTTP response")
                return false
            }
            
            // Log the status code
            logger.notice("HTTP status code: \(httpResponse.statusCode)")
            
            // Check if the status code is 200 OK
            return httpResponse.statusCode == 200
        } catch {
            logger.error("Error testing URL: \(error.localizedDescription)")
            return false
        }
    }
} 