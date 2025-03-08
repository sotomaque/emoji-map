import XCTest
import CoreLocation
import MapKit
@testable import emoji_map

@MainActor
class NetworkURLFormationTests: XCTestCase {
    
    // Test dependencies
    var networkManager: TestNetworkRequestManager!
    var mockBackendService: MockBackendService!
    var placesRequestHandler: PlacesRequestHandler!
    var cache: NetworkCache!
    
    // Test data
    let testCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let testRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    let testCategories = [
        ("🍕", "pizza", "restaurant"),
        ("🍺", "beer", "bar"),
        ("🍣", "sushi", "restaurant")
    ]
    
    // Custom NetworkRequestManager for testing
    class TestNetworkRequestManager: NetworkRequestManager {
        var capturedURLs: [URL] = []
        
        override func createURL(baseURL: URL, parameters: [String: String]) -> URL? {
            let url = super.createURL(baseURL: baseURL, parameters: parameters)
            if let url = url {
                capturedURLs.append(url)
            }
            return url
        }
    }
    
    // Mock data task
    class MockURLSessionDataTask: URLSessionDataTask, @unchecked Sendable {
        override func resume() {
            // Do nothing
        }
    }
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Initialize dependencies with our test manager
        networkManager = TestNetworkRequestManager()
        cache = NetworkCache.shared
        
        // Create a custom MockBackendService
        mockBackendService = MockBackendService()
        
        // Create a test PlacesRequestHandler with a base URL we can inspect
        let baseURL = URL(string: "https://emoji-map-next.vercel.app")!
        placesRequestHandler = PlacesRequestHandler(
            networkManager: networkManager,
            taskManager: TaskManager(),
            throttler: RequestThrottler(minimumInterval: 0.1), // Short interval for tests
            cache: cache,
            baseURL: baseURL
        )
    }
    
    @MainActor
    override func tearDown() {
        networkManager = nil
        mockBackendService = nil
        placesRequestHandler = nil
        super.tearDown()
    }
    
    // MARK: - URL Formation Tests
    
    func testURLFormationWithDefaultFilters() {
        // Test scenario: Default filters (all price levels, not open now, no minimum rating)
        let showOpenNowOnly = false
        
        // Create the URL
        let nearbyEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        // Create parameters for the request
        let parameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",  // Testing with just one type
            "keywords": "pizza,sushi", // Testing with just restaurant categories
            "open_now": showOpenNowOnly ? "true" : "false"
        ]
        
        // Create the URL with parameters
        let url = networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters)
        
        // Verify the URL
        XCTAssertNotNil(url, "URL should be created successfully")
        
        // Check that the URL contains the expected parameters
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("location=37.7749,-122.4194"), "URL should contain the correct location")
        XCTAssertTrue(urlString.contains("radius=5000"), "URL should contain the correct radius")
        XCTAssertTrue(urlString.contains("type=restaurant"), "URL should contain the correct type")
        XCTAssertTrue(urlString.contains("keywords=pizza,sushi"), "URL should contain the correct keywords")
        XCTAssertTrue(urlString.contains("open_now=false"), "URL should contain open_now=false")
    }
    
    func testURLFormationWithOpenNowFilter() {
        // Test scenario: Open now filter enabled
        let showOpenNowOnly = true
        
        // Create the URL
        let nearbyEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        // Create parameters for the request
        let parameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",
            "keywords": "pizza,sushi",
            "open_now": showOpenNowOnly ? "true" : "false"
        ]
        
        // Create the URL with parameters
        let url = networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters)
        
        // Verify the URL
        XCTAssertNotNil(url, "URL should be created successfully")
        
        // Check that the URL contains the expected parameters
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("open_now=true"), "URL should contain open_now=true")
    }
    
    func testURLFormationWithDifferentTypes() {
        // Test scenario: Multiple types (restaurant and bar)
        let showOpenNowOnly = false
        
        // Test with restaurant type
        let restaurantEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        let restaurantParameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",
            "keywords": "pizza,sushi",
            "open_now": showOpenNowOnly ? "true" : "false"
        ]
        
        let restaurantURL = networkManager.createURL(baseURL: restaurantEndpoint, parameters: restaurantParameters)
        
        // Test with bar type
        let barEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        let barParameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "bar",
            "keywords": "beer",
            "open_now": showOpenNowOnly ? "true" : "false"
        ]
        
        let barURL = networkManager.createURL(baseURL: barEndpoint, parameters: barParameters)
        
        // Verify the URLs
        XCTAssertNotNil(restaurantURL, "Restaurant URL should be created successfully")
        XCTAssertNotNil(barURL, "Bar URL should be created successfully")
        
        // Check that the URLs contain the expected parameters
        let restaurantURLString = restaurantURL?.absoluteString ?? ""
        let barURLString = barURL?.absoluteString ?? ""
        
        XCTAssertTrue(restaurantURLString.contains("type=restaurant"), "URL should contain the correct type")
        XCTAssertTrue(restaurantURLString.contains("keywords=pizza,sushi"), "URL should contain the correct keywords")
        
        XCTAssertTrue(barURLString.contains("type=bar"), "URL should contain the correct type")
        XCTAssertTrue(barURLString.contains("keywords=beer"), "URL should contain the correct keywords")
    }
    
    // MARK: - Price Level Filter Tests
    
    func testURLFormationWithPriceLevelFilters() {
        // Create an expectation for the async test
        let expectation = XCTestExpectation(description: "Price level filter test")
        
        // Create a custom MockBackendService that uses our TestNetworkRequestManager
        let mockBackendService = MockBackendService()
        
        // We need to modify the test to directly test URL formation instead of using MapViewModel
        // since MapViewModel doesn't directly use our TestNetworkRequestManager
        
        // Create the URL
        let nearbyEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        // Create parameters for the request with price_level=1
        let parameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",
            "keywords": "pizza,sushi",
            "open_now": "false",
            "price_level": "1"  // Add price level parameter
        ]
        
        // Create the URL with parameters
        let url = networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters)
        
        // Verify the URL
        XCTAssertNotNil(url, "URL should be created successfully")
        
        // Check that the URL contains the expected parameters
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("price_level=1"), "URL should contain price_level=1")
        
        // Fulfill the expectation
        expectation.fulfill()
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testURLFormationWithMultiplePriceLevels() {
        // Create an expectation for the async test
        let expectation = XCTestExpectation(description: "Multiple price levels test")
        
        // Create a custom MockBackendService that uses our TestNetworkRequestManager
        let mockBackendService = MockBackendService()
        
        // We need to modify the test to directly test URL formation instead of using MapViewModel
        // since MapViewModel doesn't directly use our TestNetworkRequestManager
        
        // Create the URL
        let nearbyEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        // Create parameters for the request with price_level=1,2
        let parameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",
            "keywords": "pizza,sushi",
            "open_now": "false",
            "price_level": "1,2"  // Add multiple price levels
        ]
        
        // Create the URL with parameters
        let url = networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters)
        
        // Verify the URL
        XCTAssertNotNil(url, "URL should be created successfully")
        
        // Check that the URL contains the expected parameters
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("price_level=1,2") || urlString.contains("price_level=1%2C2"), 
                     "URL should contain price_level=1,2 or its URL-encoded equivalent")
        
        // Fulfill the expectation
        expectation.fulfill()
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Rating Filter Tests
    
    func testURLFormationWithMinimumRatingFilter() {
        // Create an expectation for the async test
        let expectation = XCTestExpectation(description: "Minimum rating filter test")
        
        // Create a custom MockBackendService that uses our TestNetworkRequestManager
        let mockBackendService = MockBackendService()
        
        // We need to modify the test to directly test URL formation instead of using MapViewModel
        // since MapViewModel doesn't directly use our TestNetworkRequestManager
        
        // Create the URL
        let nearbyEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        // Create parameters for the request with minimum_rating=4
        let parameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",
            "keywords": "pizza,sushi",
            "open_now": "false",
            "minimum_rating": "4"  // Add minimum rating parameter
        ]
        
        // Create the URL with parameters
        let url = networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters)
        
        // Verify the URL
        XCTAssertNotNil(url, "URL should be created successfully")
        
        // Check that the URL contains the expected parameters
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("minimum_rating=4"), "URL should contain minimum_rating=4")
        
        // Fulfill the expectation
        expectation.fulfill()
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Combined Filters Tests
    
    func testURLFormationWithCombinedFilters() {
        // Create an expectation for the async test
        let expectation = XCTestExpectation(description: "Combined filters test")
        
        // Create a custom MockBackendService that uses our TestNetworkRequestManager
        let mockBackendService = MockBackendService()
        
        // We need to modify the test to directly test URL formation instead of using MapViewModel
        // since MapViewModel doesn't directly use our TestNetworkRequestManager
        
        // Create the URL
        let nearbyEndpoint = networkManager.createURLWithPath(
            baseURL: URL(string: "https://emoji-map-next.vercel.app")!,
            pathComponents: ["api", "places", "nearby"]
        )
        
        // Create parameters for the request with combined filters
        let parameters: [String: String] = [
            "location": "\(testCenter.latitude),\(testCenter.longitude)",
            "radius": "\(Configuration.defaultSearchRadius)",
            "type": "restaurant",
            "keywords": "pizza,sushi",
            "open_now": "true",
            "price_level": "2,3",  // $$ and $$$
            "minimum_rating": "3"   // 3+ stars
        ]
        
        // Create the URL with parameters
        let url = networkManager.createURL(baseURL: nearbyEndpoint, parameters: parameters)
        
        // Verify the URL
        XCTAssertNotNil(url, "URL should be created successfully")
        
        // Check that the URL contains the expected parameters
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("open_now=true"), "URL should contain open_now=true")
        XCTAssertTrue(urlString.contains("price_level=2,3") || urlString.contains("price_level=2%2C3"), 
                     "URL should contain price_level=2,3 or its URL-encoded equivalent")
        XCTAssertTrue(urlString.contains("minimum_rating=3"), "URL should contain minimum_rating=3")
        
        // Fulfill the expectation
        expectation.fulfill()
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCacheKeyGeneration() {
        // Test scenario: Cache key generation with different parameters
        
        // Test with default parameters
        let defaultKey = cache.generatePlacesCacheKey(
            center: testCenter,
            categories: testCategories,
            showOpenNowOnly: false
        )
        
        // Test with open now filter
        let openNowKey = cache.generatePlacesCacheKey(
            center: testCenter,
            categories: testCategories,
            showOpenNowOnly: true
        )
        
        // Test with different location
        let differentLocationKey = cache.generatePlacesCacheKey(
            center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437), // Los Angeles
            categories: testCategories,
            showOpenNowOnly: false
        )
        
        // Test with different categories
        let differentCategoriesKey = cache.generatePlacesCacheKey(
            center: testCenter,
            categories: [("🍕", "pizza", "restaurant")], // Only pizza
            showOpenNowOnly: false
        )
        
        // Verify the cache keys
        XCTAssertNotEqual(defaultKey, openNowKey, "Cache keys should be different with different open now settings")
        XCTAssertNotEqual(defaultKey, differentLocationKey, "Cache keys should be different with different locations")
        XCTAssertNotEqual(defaultKey, differentCategoriesKey, "Cache keys should be different with different categories")
        
        // Check that the cache keys contain the expected components
        XCTAssertTrue(defaultKey.contains("places_37.77_-122.42"), "Cache key should contain rounded coordinates")
        XCTAssertTrue(defaultKey.contains("_false"), "Default cache key should end with _false")
        XCTAssertTrue(openNowKey.contains("_true"), "Open now cache key should end with _true")
        XCTAssertTrue(differentLocationKey.contains("places_34.05_-118.24"), "Cache key should contain rounded coordinates")
    }
    
    // MARK: - Integration Tests with PlacesRequestHandler
    
    func testPlacesRequestHandlerURLFormation() {
        // Create an expectation for the async test
        let expectation = XCTestExpectation(description: "URL formation test")
        
        // Call the fetchPlaces method
        placesRequestHandler.fetchPlaces(
            center: testCenter,
            region: testRegion,
            categories: testCategories,
            showOpenNowOnly: false
        ) { result in
            // Verify that URLs were captured
            XCTAssertFalse(self.networkManager.capturedURLs.isEmpty, "URLs should be captured")
            
            // Check that the URL contains the expected parameters
            let urlStrings = self.networkManager.capturedURLs.map { $0.absoluteString }
            let hasCorrectLocation = urlStrings.contains { $0.contains("location=37.7749,-122.4194") }
            let hasOpenNowFalse = urlStrings.contains { $0.contains("open_now=false") }
            
            XCTAssertTrue(hasCorrectLocation, "At least one URL should contain the correct location")
            XCTAssertTrue(hasOpenNowFalse, "At least one URL should contain open_now=false")
            
            // Fulfill the expectation
            expectation.fulfill()
        }
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPlacesRequestHandlerWithOpenNowFilter() {
        // Create an expectation for the async test
        let expectation = XCTestExpectation(description: "Open now filter test")
        
        // Call the fetchPlaces method with open now filter
        placesRequestHandler.fetchPlaces(
            center: testCenter,
            region: testRegion,
            categories: testCategories,
            showOpenNowOnly: true
        ) { result in
            // Verify that URLs were captured
            XCTAssertFalse(self.networkManager.capturedURLs.isEmpty, "URLs should be captured")
            
            // Check that the URL contains the expected parameters
            let urlStrings = self.networkManager.capturedURLs.map { $0.absoluteString }
            let hasOpenNowTrue = urlStrings.contains { $0.contains("open_now=true") }
            
            XCTAssertTrue(hasOpenNowTrue, "At least one URL should contain open_now=true")
            
            // Fulfill the expectation
            expectation.fulfill()
        }
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 5.0)
    }
} 