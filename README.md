# Emoji Map

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

The app follows the MVVM (Model-View-ViewModel) architecture pattern:

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

- `GooglePlacesService`: Handles API communication for place data
- `LocationManager`: Manages device location updates

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

3. Set up your Google Places API key in Xcode

   - In Xcode, select your project in the Project Navigator
   - Select your app target
   - Go to the "Edit Scheme" option (Product > Scheme > Edit Scheme)
   - Select the "Run" action
   - Go to the "Arguments" tab
   - Under "Environment Variables", add "GOOGLE_PLACES_API_KEY" with your API key

4. Build and run the application

## Environment Variables

The app uses environment variables to securely manage API keys:

### Local Development

1. Set up environment variables in your Xcode scheme as described above
2. These variables will be available to the app when running in the simulator or on a device from Xcode

### CI/CD and Production

For Xcode Cloud or other CI/CD systems:

1. Add the `GOOGLE_PLACES_API_KEY` environment variable to your build configuration
2. Mark it as a secret to ensure it's not exposed in logs

### Security

- API keys are never stored in the app bundle
- Keys are read directly from the environment at runtime
- This approach prevents users from extracting your API keys from the app

## Configuration

The app uses a flexible configuration system to manage API keys and settings:

- **Environment Variables**: Primary source for API keys
- **Keychain Storage**: Secure storage for production use

For detailed configuration instructions, see the [Configuration Guide](CONFIGURATION.md).

## UI Components

The app uses a variety of custom UI components:

- **NotificationBanner**: Displays temporary messages at the bottom of the screen
- **WarningBanner**: Shows important alerts at the top of the screen
- **EmojiSelector**: Horizontal scrolling category filter
- **StarRatingView**: Interactive rating component

For details on UI components and z-index management, see the [UI Components Guide](UI_COMPONENTS.md).

## Testing

The project includes comprehensive unit tests for all major components:

### Model Tests

- `UserPreferencesTests`: Tests for favorites and ratings persistence
- `CoordinateWrapperTests`: Tests for location data encoding/decoding

### ViewModel Tests

- `MapViewModelTests`: Tests for filtering, favorites, and notifications
- `PlaceDetailViewModelTests`: Tests for place details, favorites, and ratings

### View Tests

- `StarRatingViewTests`: Tests for the rating UI component

### Service Tests

- `LocationManagerTests`: Tests for location services and updates

Run the tests in Xcode using `Cmd+U` or through the Test Navigator.

## Mock Mode

The app supports a mock mode for development and testing:

1. Set `USE_MOCK_DATA=true` in your scheme environment variables
2. Run the app to use pre-defined mock data instead of real API calls
3. A warning banner will indicate when mock mode is active

Alternatively, the app will automatically switch to mock mode if no valid API key is found.

## Thread Safety

The app implements proper thread synchronization:

- Uses `@MainActor` for UI-related view models
- Implements serial queues for shared resources
- Ensures all UI updates happen on the main thread
- Properly handles task cancellation

## Troubleshooting

If you encounter issues with the app:

1. Check the [Configuration Guide](CONFIGURATION.md) for API key setup
2. Ensure the API key is correctly set in your Xcode scheme
3. Clean the build folder and rebuild the project
4. Check the console for detailed error messages

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI framework
- [MapKit](https://developer.apple.com/documentation/mapkit/) - Map services
- [Google Places API](https://developers.google.com/maps/documentation/places/web-service/overview) - Restaurant data
- [ViewInspector](https://github.com/nalexn/ViewInspector) - SwiftUI testing library
