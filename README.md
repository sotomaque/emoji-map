# Emoji Map

<p align="center">
  <img src="emoji-map/Assets.xcassets/AppIcon.appiconset/logo-blur.png" alt="Emoji Map Logo" width="200"/>
</p>

A beautiful iOS app that helps you discover and remember your favorite restaurants using emoji categories, personalized ratings, and advanced filtering.

## Features

### 🗺️ Restaurant Discovery

- Browse restaurants on an interactive map
- Filter by food categories:
  - 🍕 Pizza
  - 🍣 Sushi
  - 🍺 Beer
  - ☕ Coffee
  - 🍔 Burger
  - 🌮 Mexican
  - 🍜 Ramen
  - 🥗 Salad
  - 🍦 Dessert
  - 🍷 Wine
  - 🍲 Asian Fusion
  - 🥪 Sandwich
- See restaurant details including photos and reviews

### ⭐ Favorites & Ratings

- Mark restaurants as favorites for quick access
- Rate restaurants from 1-5 stars
- Filter to show only your favorite places
- Combine category filters with favorites filter
- Sync ratings and favorites with the cloud when signed in

### 🔍 Advanced Filtering

- Filter by price level ($ to $$$$)
- Filter by minimum rating (1-5 stars)
- Choose between Google Maps ratings or your personal ratings
- Filter for places that are currently open
- Combine multiple filters for precise results

### 🔔 User Experience

- Smooth animations and transitions
- Haptic feedback for important actions
- Informative notifications
- Accessibility support for all users
- Responsive UI that adapts to different device sizes

### 👤 User Accounts

- Sign in with email or social providers
- Sync your favorites and ratings across devices
- Secure authentication with Clerk
- Automatic data synchronization

### 🧪 Testing & Quality

- Comprehensive unit test coverage
- Mock data support for development and testing
- Thread-safe implementation for reliable performance
- Optimized for performance with minimal memory usage

## Documentation

- [Configuration Guide](CONFIGURATION.md) - API keys and app configuration
- [UI Components Guide](UI_COMPONENTS.md) - UI components and z-index management

## Architecture

The app follows a modern MVVM (Model-View-ViewModel) architecture pattern with a service-oriented approach:

<p align="center">
  <img src="https://mermaid.ink/img/pako:eNqNkk1PwzAMhv9KlBMgdYceuExs4sQFcUHixKGqnDZbQ5o6SdVWVf_7krYb0hgCLpHjvI_fOPZJKa2QJWqnrYNXbQxsYGvBwZM2FVhYGlMBfIKtYQ0fYMFZA1ZXYJyGLTjQFVSwA-cNONhrZ6HQtgYHhVEVWNAOXg3UUJrSgK5hDU9QgYUP0BZ2YMrGQK5LWIHWFVRQGVc3Vk8wHo_hXm_qxpYwm81gofUWbDnBeDKBB11WtbFlY6qJmc1msNRlCaacYDKdwlLvwJQTTGczmBtVgqkmOJvP4VFVBZhygml-DnO1A1NPMD0_h4VWBZhqgmk-h6VagVETnOXnsNBqB6aaYJrP4UlVJZhygmk-h5VWJZhqgmk-h5VWOzDVBGf5HFZalWCqCab5HJ61KsGUE0zzOay1KsFUE0zzOay12oGpJpjmc1hrVYKpJpjmc3jRqgRTTjDN5_CqVQmmnGCaz-FNqxJMNcE0n8ObVjsw1QTTfA7vWpVgqgmm+Rw-tCrBlBNM8zl8alWCKSeY5nP40qoEU00wzefwrVUJppxgms_hR6sSTDnBNJ_Dr1YlmGqCaT6HP612YKoJpvkcfrUqwVQTTPM5_GlVgqkmmOZzuNeqBFNOMM3ncK9VCaacYJrP4UGrEkw5wTSfw6NWJZhqgmk-hyetSjDlBNN8Dk9alWDKCab5HJ61KsFUE0zzOTxrVYIpJ5jmc3jRqgRTTjDN5_CiVQmmnGCaz-FVqxJMOcE0n8ObViWYcoJpPoc3rUow5QTTfA7vWpVgygmm-Rw-tCrBlBNM8zl8aFWCKSeY5nP41KoEU04wzefwpVUJppxgms_hW6sSTDnBNJ_Dj1YlmHKCaT6HH61KMOUE03wOv1qVYMoJpvkc_rQqwZQTTPM5_GlVgikn-A9QVhQR" alt="Architecture Diagram" width="800"/>
</p>

### Models

- `Place`: Represents a restaurant with basic information
- `PlaceDetails`: Contains detailed information about a restaurant
- `FavoritePlace`: Stores user's favorite restaurants
- `PlaceRating`: Manages user's ratings for restaurants
- `UserPreferences`: Handles persistence of favorites and ratings
- `User`: Represents the authenticated user and their data

### ViewModels

- `HomeViewModel`: Manages the map state, filtering, and place discovery
- `PlaceDetailViewModel`: Handles detailed information for a selected place
- `LocationManager`: Provides user location services
- `FilterViewModel`: Manages the filtering logic for places

### Views

- `ContentView`: Main map interface with filtering controls
- `PlaceDetailView`: Detailed view of a restaurant with rating controls
- `EmojiSelector`: Category filter component
- `StarRatingView`: Interactive rating component
- `FilterView`: Advanced filtering interface for price, ratings, and more

### Services

- `NetworkService`: Handles API communication with our backend server
- `PlacesService`: Manages fetching and caching of place data
- `LocationManager`: Manages device location updates
- `ServiceContainer`: Central dependency injection container
- `HapticsManager`: Manages haptic feedback
- `UserPreferences`: Manages user preferences and local storage

## Backend Architecture

The app uses a modern backend architecture with a RESTful API:

The app communicates with our backend server at `https://emoji-map.com` which provides:

- Restaurant data from various sources
- Caching and optimization
- API key management (keeping sensitive keys secure)
- Data transformation and filtering
- User data synchronization
- Favorites and ratings storage

## Filtering System

The app implements a sophisticated filtering system that allows users to:

1. **Filter by Price Level**: Select one or more price ranges ($ to $$$$)
2. **Filter by Rating**: Choose a minimum star rating (1-5)
3. **Rating Source Selection**: Toggle between Google Maps ratings or personal ratings
4. **Open Now Filter**: Show only places that are currently open
5. **Category Filtering**: Filter by food type using emoji categories
6. **Favorites Filter**: Show only places you've marked as favorites

All filters can be combined for precise results, and the filtering UI provides visual feedback on active filters.

## Caching System

The app implements a sophisticated caching system to improve performance and reduce API calls:

The `NetworkCache` class provides:

- Configurable cache expiration times (7 days for places, 1 hour for details by default)
- Memory-efficient storage with automatic cleanup
- Thread-safe implementation
- Cache statistics for monitoring
- User-configurable settings via the app interface
- Automatic cache invalidation on memory warnings

Key features:

- Cached restaurant data is stored with location-based keys
- Cache entries automatically expire after configurable time periods
- Cache is cleared on memory warnings to prevent app crashes
- Users can manually clear the cache or adjust expiration times

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

### Installation

1. Clone the repository

```bash
git clone https://github.com/sotomaque/emoji-map.git
```

2. Open the project in Xcode

```bash
cd emoji-map
open emoji-map.xcodeproj
```

3. Build and run the application

## Configuration

The app uses a central configuration system to manage settings through the **Configuration.swift** file.

For detailed configuration instructions, see the [Configuration Guide](CONFIGURATION.md).

## UI Components

The app uses a variety of custom UI components:

- **NotificationBanner**: Displays temporary messages at the bottom of the screen
- **WarningBanner**: Shows important alerts at the top of the screen
- **EmojiSelector**: Horizontal scrolling category filter
- **StarRatingView**: Interactive rating component
- **MetalBackgroundView**: Custom Metal-based animated background
- **FilterView**: Advanced filtering interface with animated buttons
- **FilterCard**: Reusable card component for filter sections

For details on UI components and z-index management, see the [UI Components Guide](UI_COMPONENTS.md).

## Testing

The project includes unit and UI tests for key components:

### Unit Tests

- `BasicTest`: Tests basic functionality and HomeViewModel initialization

  - Verifies that the HomeViewModel can be properly instantiated
  - Confirms that the correct number of categories are loaded

- `NetworkURLFormationTests`: Tests network request URL formation
  - Validates URL formation with default filters
  - Tests URL formation with open now filter
  - Verifies URL formation with different place types
  - Tests URL formation with price level filters
  - Validates URL formation with multiple price levels

### UI Tests

- `BasicUITest`: Tests basic app functionality
  - Verifies that the app launches successfully

The test suite is continuously expanded as new features are added. Run the tests in Xcode using `Cmd+U` or through the Test Navigator.

## Thread Safety

The app implements proper thread synchronization:

- Uses `@MainActor` for UI-related view models
- Implements serial queues for shared resources
- Ensures all UI updates happen on the main thread
- Properly handles task cancellation
- Uses thread-safe property access patterns

## Troubleshooting

If you encounter issues with the app:

1. Clean the build folder and rebuild the project
2. Check the console for detailed error messages
3. Try clearing the app cache in Settings

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI framework
- [MapKit](https://developer.apple.com/documentation/mapkit/) - Map services
- [Metal](https://developer.apple.com/metal/) - Graphics framework
- [ViewInspector](https://github.com/nalexn/ViewInspector) - SwiftUI testing library
- [Clerk](https://clerk.com/) - Authentication provider
