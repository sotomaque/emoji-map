# Configuration Guide for Emoji Map

This document explains how to configure the Emoji Map application, particularly focusing on API keys and environment variables.

## Configuration Files

Emoji Map uses the following configuration files:

### 1. Info.plist

This is the main information property list file for the application. During the build process, the API key is automatically injected into this file from environment variables.

### 2. CustomInfo.plist

This is the main information property list file for the application. It contains:

- Standard iOS app configuration (bundle ID, version, etc.)
- Permission descriptions
- UI configuration

Location: `emoji-map/CustomInfo.plist`

## API Key Configuration

### Google Places API Key

The app requires a Google Places API key to fetch restaurant data. The key is retrieved in the following order:

1. From Xcode environment variables (primary source)
2. From the device keychain (for production)

If no key is found, the app falls back to mock data mode.

## Setting Up Environment Variables

### For Local Development (Simulator and Device)

1. In Xcode, select your project in the Project Navigator
2. Select your app target
3. Go to the "Edit Scheme" option (Product > Scheme > Edit Scheme)
4. Select the "Run" action
5. Go to the "Arguments" tab
6. Under "Environment Variables", click the "+" button
7. Add a variable with name "GOOGLE_PLACES_API_KEY" and your actual API key as the value
8. Make sure the checkbox next to it is checked

This will set the environment variable for your app when running in the simulator or on a device from Xcode.

### For CI/CD and Production (Xcode Cloud)

1. In App Store Connect, go to your app's Xcode Cloud workflow
2. Add an environment variable named "GOOGLE_PLACES_API_KEY" with your API key
3. Make sure it's marked as a secret for security

## Obtaining a Google Places API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Places API for your project
4. Create an API key
5. Add the key to your Xcode environment variables as described above

## Mock Data Mode

If no valid API key is found, the app automatically switches to mock data mode:

- A warning banner appears in the app
- Pre-defined sample data is used instead of API calls
- Useful for development and testing without API quota usage

## Security Considerations

For production builds:

1. Never commit API keys to source control
2. Use environment variables for key injection
3. Consider implementing API key restrictions in the Google Cloud Console
4. The API key is never stored in the app bundle, making it impossible for users to extract it

## Troubleshooting

### API Key Not Found

If the app shows "API key not configured properly":

1. Verify the `GOOGLE_PLACES_API_KEY` environment variable is set in your Xcode scheme
2. Check that the variable name is exactly "GOOGLE_PLACES_API_KEY"
3. Make sure the checkbox next to the environment variable is checked
4. Clean and rebuild the project

### Device Testing

When testing on a physical device:

1. Make sure you're running the app directly from Xcode
2. The environment variables set in your Xcode scheme will be passed to the app
3. If you install the app through TestFlight or the App Store, the environment variables from Xcode Cloud will be used

## Example CI/CD Configuration

### Xcode Cloud

1. In App Store Connect, go to your app's Xcode Cloud workflow
2. Add an environment variable named `GOOGLE_PLACES_API_KEY` with your API key
3. Make sure the variable is marked as "secret" for security

### GitHub Actions

```yaml
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up environment
        env:
          GOOGLE_PLACES_API_KEY: ${{ secrets.GOOGLE_PLACES_API_KEY }}
        run: |
          echo "GOOGLE_PLACES_API_KEY=$GOOGLE_PLACES_API_KEY" > .env
      - name: Build and test
        run: |
          xcodebuild -scheme emoji-map -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Fastlane

```ruby
lane :beta do
  # Set environment variables
  ENV["GOOGLE_PLACES_API_KEY"] = ENV["GOOGLE_PLACES_API_KEY"] || prompt(text: "Enter Google Places API Key: ")

  # Build the app
  build_app(scheme: "emoji-map")

  # Upload to TestFlight
  upload_to_testflight
end
```
