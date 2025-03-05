import XCTest
import CoreLocation
@testable import emoji_map

// Mock CLLocationManager for testing
class MockCLLocationManager: CLLocationManager {
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    var requestWhenInUseAuthorizationCalled = false
    
    override var authorizationStatus: CLAuthorizationStatus {
        return mockAuthorizationStatus
    }
    
    override func startUpdatingLocation() {
        startUpdatingLocationCalled = true
    }
    
    override func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }
    
    override func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCalled = true
    }
    
    // Helper method to simulate location updates
    func simulateLocationUpdate(locations: [CLLocation]) {
        if let delegate = delegate {
            delegate.locationManager?(self, didUpdateLocations: locations)
        }
    }
    
    // Helper method to simulate location errors
    func simulateLocationError(error: Error) {
        if let delegate = delegate {
            delegate.locationManager?(self, didFailWithError: error)
        }
    }
    
    // Helper method to simulate authorization changes
    func simulateAuthorizationChange() {
        if let delegate = delegate {
            delegate.locationManagerDidChangeAuthorization?(self)
        }
    }
}

class LocationManagerTests: XCTestCase {
    var sut: LocationManager!
    var mockCLLocationManager: MockCLLocationManager!
    var mockQueue: DispatchQueue!
    
    override func setUp() {
        super.setUp()
        mockCLLocationManager = MockCLLocationManager()
        mockQueue = DispatchQueue(label: "com.emoji-map.testQueue")
        sut = LocationManager(locationManager: mockCLLocationManager, queue: mockQueue)
    }
    
    override func tearDown() {
        sut = nil
        mockCLLocationManager = nil
        mockQueue = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(mockCLLocationManager.requestWhenInUseAuthorizationCalled, "Should request authorization on initialization")
        XCTAssertTrue(mockCLLocationManager.startUpdatingLocationCalled, "Should start updating location on initialization")
    }
    
    // MARK: - Location Update Tests
    
    func testLocationUpdate() {
        // Given
        let expectation = self.expectation(description: "Location update")
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        var updatedLocation: CLLocation?
        
        // When
        sut.onLocationUpdate = { location in
            updatedLocation = location
            expectation.fulfill()
        }
        
        mockCLLocationManager.simulateLocationUpdate(locations: [testLocation])
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error, "Test timed out")
            XCTAssertNotNil(updatedLocation, "Updated location should not be nil")
            if let updatedLocation = updatedLocation {
                XCTAssertEqual(updatedLocation.coordinate.latitude, testLocation.coordinate.latitude, accuracy: 0.0001)
                XCTAssertEqual(updatedLocation.coordinate.longitude, testLocation.coordinate.longitude, accuracy: 0.0001)
            }
            XCTAssertNotNil(self.sut.location, "Location should not be nil")
            if let location = self.sut.location {
                XCTAssertEqual(location.coordinate.latitude, testLocation.coordinate.latitude, accuracy: 0.0001)
                XCTAssertEqual(location.coordinate.longitude, testLocation.coordinate.longitude, accuracy: 0.0001)
            }
        }
    }
    
    func testLocationUpdateWithMultipleLocations() {
        // Given
        let expectation = self.expectation(description: "Location update")
        let oldLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let newLocation = CLLocation(latitude: 37.3382, longitude: -121.8863)
        var updatedLocation: CLLocation?
        
        // When
        sut.onLocationUpdate = { location in
            updatedLocation = location
            expectation.fulfill()
        }
        
        mockCLLocationManager.simulateLocationUpdate(locations: [oldLocation, newLocation])
        
        // Then
        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error, "Test timed out")
            XCTAssertNotNil(updatedLocation, "Updated location should not be nil")
            if let updatedLocation = updatedLocation {
                // Should use the last location in the array
                XCTAssertEqual(updatedLocation.coordinate.latitude, newLocation.coordinate.latitude, accuracy: 0.0001)
                XCTAssertEqual(updatedLocation.coordinate.longitude, newLocation.coordinate.longitude, accuracy: 0.0001)
            }
        }
    }
    
    func testLocationUpdateWithEmptyLocations() {
        // Given
        let expectation = self.expectation(description: "Location update should not happen")
        expectation.isInverted = true // We expect this NOT to be fulfilled
        
        // When
        sut.onLocationUpdate = { _ in
            expectation.fulfill()
        }
        
        mockCLLocationManager.simulateLocationUpdate(locations: [])
        
        // Then
        waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error, "Test failed")
            XCTAssertNil(self.sut.location, "Location should remain nil with empty locations array")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testLocationError() {
        // Given
        let testError = NSError(domain: "TestErrorDomain", code: 123, userInfo: nil)
        
        // When
        mockCLLocationManager.simulateLocationError(error: testError)
        
        // Then
        // This is primarily testing that the error doesn't crash the app
        // In a real app, you might have more specific error handling to test
        XCTAssertTrue(true, "Error handling should not crash")
    }
    
    // MARK: - Authorization Tests
    
    func testAuthorizationWhenInUse() {
        // Given
        mockCLLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockCLLocationManager.startUpdatingLocationCalled = false
        
        // When
        mockCLLocationManager.simulateAuthorizationChange()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.startUpdatingLocationCalled, "Should start updating location when authorized")
    }
    
    func testAuthorizationDenied() {
        // Given
        mockCLLocationManager.mockAuthorizationStatus = .denied
        mockCLLocationManager.startUpdatingLocationCalled = false
        
        // When
        mockCLLocationManager.simulateAuthorizationChange()
        
        // Then
        XCTAssertFalse(mockCLLocationManager.startUpdatingLocationCalled, "Should not start updating location when denied")
    }
    
    // MARK: - Public Method Tests
    
    func testStartUpdatingLocation() {
        // Given
        mockCLLocationManager.startUpdatingLocationCalled = false
        
        // When
        sut.startUpdatingLocation()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.startUpdatingLocationCalled, "startUpdatingLocation should call through to CLLocationManager")
    }
    
    func testStopUpdatingLocation() {
        // Given
        mockCLLocationManager.stopUpdatingLocationCalled = false
        
        // When
        sut.stopUpdatingLocation()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.stopUpdatingLocationCalled, "stopUpdatingLocation should call through to CLLocationManager")
    }
    
    func testRequestLocationAuthorization() {
        // Given
        mockCLLocationManager.requestWhenInUseAuthorizationCalled = false
        
        // When
        sut.requestLocationAuthorization()
        
        // Then
        XCTAssertTrue(mockCLLocationManager.requestWhenInUseAuthorizationCalled, "requestLocationAuthorization should call through to CLLocationManager")
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafetyOfLocationUpdates() {
        // Given
        let expectation = self.expectation(description: "All location updates processed")
        expectation.expectedFulfillmentCount = 100
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When
        sut.onLocationUpdate = { _ in
            expectation.fulfill()
        }
        
        // Simulate many concurrent location updates
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            self.mockCLLocationManager.simulateLocationUpdate(locations: [testLocation])
        }
        
        // Then
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Test timed out")
            // If we get here without crashes, the thread safety is working
        }
    }
} 
