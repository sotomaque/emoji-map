# Emoji Map

<p align="center">
  <img src="emoji-map/Assets.xcassets/AppIcon.appiconset/logo-blur.png" alt="Emoji Map Logo" width="200"/>
</p>

A beautiful iOS app that helps you discover and remember your favorite restaurants using emoji categories and personalized ratings.

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

### 🔔 User Experience

- Smooth animations and transitions
- Haptic feedback for important actions
- Informative notifications
- Accessibility support for all users

### 🧪 Testing & Quality

- Comprehensive unit test coverage
- Mock data support for development and testing
- Thread-safe implementation for reliable performance

## Documentation

- [Configuration Guide](CONFIGURATION.md) - API keys and app configuration
- [UI Components Guide](UI_COMPONENTS.md) - UI components and z-index management

## Architecture

The app follows a modern MVVM (Model-View-ViewModel) architecture pattern with a service-oriented approach:

<p align="center">
  <img src="https://mermaid.ink/img/pako:eNqNkk1PwzAMhv9KlBMgdYceuExs4sQFcUHixKGqnDZbQ5o6SdVWVf_7krYb0hgCLpHjvI_fOPZJKa2QJWqnrYNXbQxsYGvBwZM2FVhYGlMBfIKtYQ0fYMFZA1ZXYJyGLTjQFVSwA-cNONhrZ6HQtgYHhVEVWNAOXg3UUJrSgK5hDU9QgYUP0BZ2YMrGQK5LWIHWFVRQGVc3Vk8wHo_hXm_qxpYwm81gofUWbDnBeDKBB11WtbFlY6qJmc1msNRlCaacYDKdwlLvwJQTTGczmBtVgqkmOJvP4VFVBZhygml-DnO1A1NPMD0_h4VWBZhqgmk-h6XagVETnOXnsNBqB6aaYJrP4UlVJZhygmk-h5VWJZhqgmk-h5VWOzDVBGf5HFZalWCqCab5HJ61KsGUE0zzOay1KsFUE0zzOay12oGpJpjmc1hrVYKpJpjmc3jRqgRTTjDN5_CqVQmmnGCaz-FNqxJMNcE0n8ObVjsw1QTTfA7vWpVgqgmm+Rw-tCrBlBNM8zl8alWCKSeY5nP40qoEU00wzefwrVUJppxgms_hR6sSTDnBNJ_Dr1YlmGqCaT6HP612YKoJpvkcfrUqwVQTTPM5_GlVgqkmmOZzuNeqBFNOMM3ncK9VCaacYJrP4UGrEkw5wTSfw6NWJZhqgmk-hyetSjDlBNN8Dk9alWDKCab5HJ61KsFUE0zzOTxrVYIpJ5jmc3jRqgRTTjDN5_CiVQmmnGCaz-FVqxJMOcE0n8ObViWYcoJpPoc3rUow5QTTfA7vWpVgygmm+Rw-tCrBlBNM8zl8aFWCKSeY5nP41KoEU04wzefwpVUJppxgms_hW6sSTDnBNJ_Dj1YlmHKCaT6HH61KMOUE03wOv1qVYMoJpvkc_rQqwZQTTPM5_GlVgikn-A9QVhQR" alt="Architecture Diagram" width="800"/>
</p>

### Models

- `Place`: Represents a restaurant with basic information
- `PlaceDetails`: Contains detailed information about a restaurant
- `FavoritePlace`: Stores user's favorite restaurants
- `PlaceRating`: Manages user's ratings for restaurants
- `UserPreferences`: Handles persistence of favorites and ratings

### ViewModels

- `MapViewModel`: Manages the map state, filtering, and place discovery
- `PlaceDetailViewModel`: Handles detailed information for a selected place
- `LocationManager`: Provides user location services

### Views

- `ContentView`: Main map interface with filtering controls
- `PlaceDetailView`: Detailed view of a restaurant with rating controls
- `EmojiSelector`: Category filter component
- `StarRatingView`: Interactive rating component

### Services

- `BackendService`: Handles API communication with our backend server
- `LocationManager`: Manages device location updates
- `ServiceContainer`: Central dependency injection container
- `HapticsManager`: Manages haptic feedback
- `MapAppUtility`: Handles external map app integration

## Backend Architecture

The app uses a modern backend architecture with a RESTful API:

<p align="center">
  <img src="https://mermaid.ink/img/pako:eNqNksFuwjAMhl_FyglQ2aGHXiZtJ06bxIXtxKGKnLZZQ5o6SQVFvPuStlDYGBqXKLH_z78dO0dltEaWqL22Hl6NtbCBrQMPT8bWYGFpbQ3wCa5hDR_gwlsDTtfgvIMteDBVrGAPPhjwcDDewdK0Dhx4a2BtXQOlrSy4GtawAg8OPsE52IMtWweFqWAF2tSwgtr6prVmgvF4DPdm07S2gul0CgvjtuDKCcaTCTyYqm6cq1pXT8x0OoWlqSpw5QST6RSWZg-2nGA6mcDcqgpcPcHZbAaPuirBVhNM8zk8mj24ZoLpbAYLowpw9QTTfA4LowpwzQTTfA5LowpwzQTTfA5LrfbgmgmmuYeFVgW4ZoJpPoelVgW4ZoJpPoelVntwzQTTfA4rrQpwzQTTfA4rrQpwzQTTfA4rrfbgmgmm-RxWWhXgmgmm-RyetSrANRNM8zk8a1WAayaY5nN41moProHJZALPWhXgmgmm-RxetCrANRNM8zm8aFWAayaY5nN41WoPrplgms_hVasCXDPBNJ_Dm1YFuGaCaT6HN60KcM0E03wOb1rtwTUTTPM5vGtVgGsmmOZzeNeqANdMMM3n8KFVAa6ZYJrP4UOrAlwzwTSfw6dWBbhmgmk-h0-t9uCaCab5HL61KsA1E0zzOXxrVYBrJpjmc_jWqgDXTDDN5_CjVQGumWCaz-FHqwJcM8E0n8OvVgW4ZoJpPodfrcpYwP9QVhQR" alt="Backend Architecture" width="800"/>
</p>

The app communicates with our backend server at `https://emoji-map-next.vercel.app` which provides:

- Restaurant data from various sources
- Caching and optimization
- API key management (keeping sensitive keys secure)
- Data transformation and filtering

## Caching System

The app implements a sophisticated caching system to improve performance and reduce API calls:

<p align="center">
  <img src="https://mermaid.ink/img/pako:eNqNksFuwjAMhl_FyglQ2aGHXiZtJ06bxIXtxKGKnLZZQ5o6SQVFvPuStlDYGBqXKLH_z78dO0dltEaWqL22Hl6NtbCBrQMPT8bWYGFpbQ3wCa5hDR_gwlsDTtfgvIMteDBVrGAPPhjwcDDewdK0Dhx4a2BtXQOlrSy4GtawAg8OPsE52IMtWweFqWAF2tSwgtr6prVmgvF4DPdm07S2gul0CgvjtuDKCcaTCTyYqm6cq1pXT8x0OoWlqSpw5QST6RSWZg-2nGA6mcDcqgpcPcHZbAaPuirBVhNM8zk8mj24ZoLpbAYLowpw9QTTfA4LowpwzQTTfA5LowpwzQTTfA5LrfbgmgmmuYeFVgW4ZoJpPoelVgW4ZoJpPoelVntwzQTTfA4rrQpwzQTTfA4rrQpwzQTTfA4rrfbgmgmm-RxWWhXgmgmm-RyetSrANRNM8zk8a1WAayaY5nN41moProHJZALPWhXgmgmm-RxetCrANRNM8zm8aFWAayaY5nN41WoPrplgms_hVasCXDPBNJ_Dm1YFuGaCaT6HN60KcM0E03wOb1rtwTUTTPM5vGtVgGsmmOZzeNeqANdMMM3n8KFVAa6ZYJrP4UOrAlwzwTSfw6dWBbhmgmk-h0-t9uCaCab5HL61KsA1E0zzOXxrVYBrJpjmc_jWqgDXTDDN5_CjVQGumWCaz-FHqwJcM8E0n8OvVgW4ZoJpPodfrcpYwP9QVhQR" alt="Caching System" width="800"/>
</p>

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

For details on UI components and z-index management, see the [UI Components Guide](UI_COMPONENTS.md).

## Testing

The project includes unit and UI tests for key components:

### Unit Tests

- `BasicTest`: Tests basic functionality and MapViewModel initialization

  - Verifies that the MapViewModel can be properly instantiated
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
