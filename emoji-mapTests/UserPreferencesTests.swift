import XCTest
import CoreLocation
@testable import emoji_map

class UserPreferencesTests: XCTestCase {
    var sut: UserPreferences!
    var testPlace: Place!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults for testing
        let userDefaultsSuiteName = "com.emoji-map.tests"
        let testDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        testDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        
        // Create a test place
        testPlace = Place(
            placeId: "test_place_id",
            name: "Test Restaurant",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            category: "pizza",
            description: "A test restaurant",
            priceLevel: 2,
            openNow: true,
            rating: 4.5
        )
        
        // Initialize the system under test
        sut = UserPreferences(userDefaults: testDefaults)
    }
    
    override func tearDown() {
        sut = nil
        testPlace = nil
        super.tearDown()
    }
    
    // MARK: - Favorites Tests
    
    func testAddFavorite() {
        // When
        sut.addFavorite(testPlace)
        
        // Then
        XCTAssertTrue(sut.isFavorite(placeId: testPlace.placeId), "Place should be marked as favorite")
        XCTAssertEqual(sut.favorites.count, 1, "Should have 1 favorite")
    }
    
    func testRemoveFavorite() {
        // Given
        sut.addFavorite(testPlace)
        XCTAssertTrue(sut.isFavorite(placeId: testPlace.placeId), "Precondition: Place should be favorite")
        
        // When
        sut.removeFavorite(placeId: testPlace.placeId)
        
        // Then
        XCTAssertFalse(sut.isFavorite(placeId: testPlace.placeId), "Place should no longer be favorite")
        XCTAssertEqual(sut.favorites.count, 0, "Should have 0 favorites")
    }
    
    func testAddDuplicateFavorite() {
        // Given
        sut.addFavorite(testPlace)
        XCTAssertEqual(sut.favorites.count, 1, "Precondition: Should have 1 favorite")
        
        // When
        sut.addFavorite(testPlace)
        
        // Then
        XCTAssertEqual(sut.favorites.count, 1, "Should still have only 1 favorite")
    }
    
    func testIsFavorite() {
        // Given
        XCTAssertFalse(sut.isFavorite(placeId: testPlace.placeId), "Precondition: Place should not be favorite")
        
        // When
        sut.addFavorite(testPlace)
        
        // Then
        XCTAssertTrue(sut.isFavorite(placeId: testPlace.placeId), "Place should be marked as favorite")
        
        // When
        sut.removeFavorite(placeId: testPlace.placeId)
        
        // Then
        XCTAssertFalse(sut.isFavorite(placeId: testPlace.placeId), "Place should no longer be favorite")
    }
    
    // MARK: - Ratings Tests
    
    func testRatePlace() {
        // When
        sut.ratePlace(placeId: testPlace.placeId, rating: 4)
        
        // Then
        XCTAssertEqual(sut.getRating(for: testPlace.placeId), 4, "Rating should be 4")
    }
    
    func testUpdateRating() {
        // Given
        sut.ratePlace(placeId: testPlace.placeId, rating: 3)
        XCTAssertEqual(sut.getRating(for: testPlace.placeId), 3, "Precondition: Rating should be 3")
        
        // When
        sut.ratePlace(placeId: testPlace.placeId, rating: 5)
        
        // Then
        XCTAssertEqual(sut.getRating(for: testPlace.placeId), 5, "Rating should be updated to 5")
    }
    
    func testRatingBounds() {
        // When - Try to set rating below minimum
        sut.ratePlace(placeId: testPlace.placeId, rating: -1)
        
        // Then
        XCTAssertEqual(sut.getRating(for: testPlace.placeId), 0, "Rating should be clamped to minimum (0)")
        
        // When - Try to set rating above maximum
        sut.ratePlace(placeId: testPlace.placeId, rating: 10)
        
        // Then
        XCTAssertEqual(sut.getRating(for: testPlace.placeId), 5, "Rating should be clamped to maximum (5)")
    }
    
    func testGetNonexistentRating() {
        // When/Then
        XCTAssertNil(sut.getRating(for: "nonexistent_id"), "Should return nil for nonexistent rating")
    }
    
    // MARK: - Persistence Tests
    
    func testFavoritesPersistence() {
        // Given
        sut.addFavorite(testPlace)
        XCTAssertTrue(sut.isFavorite(placeId: testPlace.placeId), "Precondition: Place should be favorite")
        
        // When - Create a new instance with the same UserDefaults
        let newPreferences = UserPreferences(userDefaults: sut.userDefaults)
        
        // Then
        XCTAssertTrue(newPreferences.isFavorite(placeId: testPlace.placeId), "Favorite status should persist")
        XCTAssertEqual(newPreferences.favorites.count, 1, "Should have 1 favorite after reload")
    }
    
    func testRatingsPersistence() {
        // Given
        sut.ratePlace(placeId: testPlace.placeId, rating: 4)
        XCTAssertEqual(sut.getRating(for: testPlace.placeId), 4, "Precondition: Rating should be 4")
        
        // When - Create a new instance with the same UserDefaults
        let newPreferences = UserPreferences(userDefaults: sut.userDefaults)
        
        // Then
        XCTAssertEqual(newPreferences.getRating(for: testPlace.placeId), 4, "Rating should persist")
    }
} 