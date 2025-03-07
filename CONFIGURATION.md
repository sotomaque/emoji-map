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

1. From environment variables (primary source)
2. From the .env file in the app bundle

If no key is found, the app falls back to mock data mode.

## Secure API Key Management

To avoid exposing API keys in source control or in the app bundle, we use environment variables:

### Environment Variables (Recommended)

1. Create a `.env` file (add to .gitignore) with your API key:

   ```
   GOOGLE_PLACES_API_KEY=your_actual_api_key_here
   ```

2. The build script automatically loads this environment variable during build time.

3. For CI/CD pipelines (like Xcode Cloud), set the environment variable directly in your build system.

### Setting Up Your API Key

1. Obtain a Google Places API key from the [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Places API for your project
3. Create a `.env` file in the project root with your API key:
   ```
   GOOGLE_PLACES_API_KEY=your_actual_api_key_here
   ```
4. For production builds, set the environment variable in your CI/CD pipeline

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
4. Ensure `.env` files are in your `.gitignore`
5. The API key is never stored in the app bundle, making it impossible for users to extract it

## Troubleshooting

### API Key Not Found

If the app shows "API key not configured properly":

1. Verify the `GOOGLE_PLACES_API_KEY` environment variable is set
2. Check that the build script is running correctly
3. Clean and rebuild the project

### CI/CD Setup

For CI/CD pipelines:

1. Set the `GOOGLE_PLACES_API_KEY` environment variable in your CI/CD system
2. Ensure the build script runs before the "Compile Sources" phase
3. Verify the environment variable is accessible to the build process

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
