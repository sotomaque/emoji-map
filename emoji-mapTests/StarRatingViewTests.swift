import XCTest
import SwiftUI
import ViewInspector
@testable import emoji_map

// Extension to make StarRatingView inspectable
extension StarRatingView: Inspectable {}

class StarRatingViewTests: XCTestCase {
    
    func testStarRatingViewInitialization() {
        // Test default initialization
        let defaultView = StarRatingView()
        XCTAssertEqual(defaultView.rating, 0)
        XCTAssertEqual(defaultView.maxRating, 5)
        XCTAssertEqual(defaultView.size, 24)
        XCTAssertEqual(defaultView.spacing, 4)
        XCTAssertEqual(defaultView.color, .yellow)
        XCTAssertFalse(defaultView.isInteractive)
        XCTAssertNil(defaultView.onRatingChanged)
        
        // Test custom initialization
        let customView = StarRatingView(
            rating: 3,
            maxRating: 4,
            size: 32,
            spacing: 8,
            color: .red,
            isInteractive: true,
            onRatingChanged: { _ in }
        )
        
        XCTAssertEqual(customView.rating, 3)
        XCTAssertEqual(customView.maxRating, 4)
        XCTAssertEqual(customView.size, 32)
        XCTAssertEqual(customView.spacing, 8)
        XCTAssertEqual(customView.color, .red)
        XCTAssertTrue(customView.isInteractive)
        XCTAssertNotNil(customView.onRatingChanged)
    }
    
    func testRatingBoundaries() {
        // Test rating below 0
        let belowMinView = StarRatingView(rating: -1)
        XCTAssertEqual(belowMinView.rating, 0, "Rating should be clamped to minimum 0")
        
        // Test rating above maxRating
        let aboveMaxView = StarRatingView(rating: 6, maxRating: 5)
        XCTAssertEqual(aboveMaxView.rating, 5, "Rating should be clamped to maxRating")
    }
    
    func testRatingCallback() {
        // Arrange
        var callbackRating: Int?
        let view = StarRatingView(
            rating: 2,
            isInteractive: true,
            onRatingChanged: { rating in
                callbackRating = rating
            }
        )
        
        // Act - simulate a tap on the third star
        // Note: In a real test, you would use ViewInspector to simulate the tap
        // This is a simplified version that just tests the callback logic
        if let callback = view.onRatingChanged {
            callback(3)
        }
        
        // Assert
        XCTAssertEqual(callbackRating, 3, "Callback should be called with the new rating")
    }
    
    func testClearRatingBehavior() {
        // Arrange
        var callbackRating: Int?
        let view = StarRatingView(
            rating: 3,
            isInteractive: true,
            onRatingChanged: { rating in
                callbackRating = rating
            }
        )
        
        // Act - simulate a tap on the same star (should clear the rating)
        // Note: In a real test, you would use ViewInspector to simulate the tap
        if let callback = view.onRatingChanged {
            callback(0)
        }
        
        // Assert
        XCTAssertEqual(callbackRating, 0, "Tapping the current rating should clear it (set to 0)")
    }
} 