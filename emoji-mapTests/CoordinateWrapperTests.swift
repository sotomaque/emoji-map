import XCTest
import CoreLocation
@testable import emoji_map

class CoordinateWrapperTests: XCTestCase {
    
    func testEquality() {
        // Given
        let coord1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord2 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord3 = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        
        let wrapper1 = CoordinateWrapper(coord1)
        let wrapper2 = CoordinateWrapper(coord2)
        let wrapper3 = CoordinateWrapper(coord3)
        
        // Then
        XCTAssertEqual(wrapper1, wrapper2, "Wrappers with same coordinates should be equal")
        XCTAssertNotEqual(wrapper1, wrapper3, "Wrappers with different coordinates should not be equal")
    }
    
    func testEncoding() throws {
        // Given
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let wrapper = CoordinateWrapper(coordinate)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(wrapper)
        let jsonString = String(data: data, encoding: .utf8)
        
        // Then
        XCTAssertNotNil(jsonString, "JSON string should not be nil")
        XCTAssertTrue(jsonString!.contains("\"latitude\":37.7749"), "JSON should contain latitude")
        XCTAssertTrue(jsonString!.contains("\"longitude\":-122.4194"), "JSON should contain longitude")
    }
    
    func testDecoding() throws {
        // Given
        let json = """
        {
            "latitude": 37.7749,
            "longitude": -122.4194
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(CoordinateWrapper.self, from: data)
        
        // Then
        XCTAssertEqual(wrapper.coordinate.latitude, 37.7749, accuracy: 0.0001, "Latitude should match")
        XCTAssertEqual(wrapper.coordinate.longitude, -122.4194, accuracy: 0.0001, "Longitude should match")
    }
    
    func testRoundTrip() throws {
        // Given
        let originalCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let originalWrapper = CoordinateWrapper(originalCoordinate)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalWrapper)
        
        let decoder = JSONDecoder()
        let decodedWrapper = try decoder.decode(CoordinateWrapper.self, from: data)
        
        // Then
        XCTAssertEqual(originalWrapper, decodedWrapper, "Round-trip encoding and decoding should preserve equality")
        XCTAssertEqual(decodedWrapper.coordinate.latitude, originalCoordinate.latitude, accuracy: 0.0001, "Latitude should be preserved")
        XCTAssertEqual(decodedWrapper.coordinate.longitude, originalCoordinate.longitude, accuracy: 0.0001, "Longitude should be preserved")
    }
} 